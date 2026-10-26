"""手元で 1 回だけ取り込む統計表 (local_tables.yml) を取得・ロードし、dbt をビルドする。

CI の main.py では e-Stat から取らない。数年に 1 度しか出ない統計を毎日取り直すと、
Sync の時間を食うため。CI の Sync は公開済みの _source の表を読んでビルドするだけ。

load_local_mesh.py と同じく取得と公開を分ける。取得をカタログの外で済ませておけば、
sync の中はファイルのロードと対象の dbt だけで数分になり、CI の Sync と重なりにくい。

    uv run --env-file .env python load_local.py fetch census_2025   # 取得 (data/local/ に保存)
    uv run queria sync -- uv run --env-file .env python load_local.py load census_2025

fetch は表ごとに Parquet を書き、書き終えた表は次から飛ばす。取得した表の e-Stat の
更新日が local_tables.yml の updated_date と食い違うと止まる (見張りの基準がずれるため)。
Parquet の名前に updated_date を入れるので、yml の日付を直すと前の取得分は読まれず、
fetch は取り直し、load は取り直す前なら止まる。

fetcher を書いたグループ (ファイルで配られる統計) は pipelines/<fetcher>.py の fetch_local が
取得し、表ごとの updated_date の代わりに catalog_modified_date で食い違いを見る。
"""

import importlib
import logging
import os
import sys
from pathlib import Path

import dlt
import pyarrow as pa
import pyarrow.compute as pc
import pyarrow.parquet as pq
import yaml
from estat_api_dlt_helper import EstatApiClient, estat_table

from main import dbt_build
from pipelines import EstatStatus, create_pipeline
from pipelines.ssds import drop_stat_inf

logger = logging.getLogger("pipelines")

ROOT = Path(__file__).parent
CACHE_DIR = ROOT / "data" / "local"


def load_group(name: str) -> dict:
    groups = yaml.safe_load((ROOT / "local_tables.yml").read_text())["groups"]
    if name not in groups:
        raise SystemExit(f"local_tables.yml に {name} が無い (あるのは {sorted(groups)})")
    spec = groups[name]
    if "fetcher" in spec:
        # Parquet の名前は表の updated_date から付く。catalog_modified_date だけ進めて表の日付を
        # 直し忘れると、fetch は前の取得分を「取得済み」として飛ばし、load は古い表を入れ直す
        if stale := [
            t["name"]
            for t in spec["tables"]
            if str(t["updated_date"]) != str(spec["catalog_modified_date"])
        ]:
            raise SystemExit(
                f"{name}: {stale} の updated_date が catalog_modified_date "
                f"{spec['catalog_modified_date']} と違う。同じ日付にそろえる"
            )
    elif missing := [t["name"] for t in spec["tables"] if "primary_key" not in t]:
        # 主キーを置かないのは、NULL の入る列しか無い fetcher のグループだけ
        raise SystemExit(f"{name}: {missing} に primary_key が無い")
    return spec


def class_order(app_id: str, stats_data_id: str) -> dict[str, dict[str, int]]:
    """分類軸ごとに、メタ情報の並び順 (0 始まり) をコードから引く表を返す。

    getStatsData の値にはメタ情報の並びが残らない。並びにしか入っていない階層
    (医療施設調査の二次医療圏と市区町村など) を読むときに使う。コードの順では
    代えられない (コードが並びと違う順に振られた表がある)。
    """
    client = EstatApiClient(app_id=app_id, timeout=300)
    try:
        root = client.get_stats_data(stats_data_id=stats_data_id, limit=1)
    finally:
        client.close()
    body = root["GET_STATS_DATA"]
    if int(body["RESULT"]["STATUS"]) != EstatStatus.OK:
        raise RuntimeError(
            f"{stats_data_id}: メタ情報の取得で e-Stat がエラー {body['RESULT']['STATUS']} を返した: "
            f"{body['RESULT'].get('ERROR_MSG')}"
        )
    objs = body["STATISTICAL_DATA"]["CLASS_INF"]["CLASS_OBJ"]
    order = {}
    for obj in objs if isinstance(objs, list) else [objs]:
        # CLASS を持たない分類軸がある (pipelines/meta_info.py)。並びが無いので飛ばす
        if "CLASS" not in obj:
            continue
        classes = obj["CLASS"] if isinstance(obj["CLASS"], list) else [obj["CLASS"]]
        order[obj["@id"]] = {c["@code"]: i for i, c in enumerate(classes)}
    return order


def with_class_order(table: pa.Table, order: dict[str, dict[str, int]]) -> pa.Table:
    """cat01 などの分類軸ごとに、メタ情報の並び順を <軸>_order 列として足す。"""
    for axis, positions in order.items():
        if axis.startswith("cat") and axis in table.column_names:
            values = [positions[code] for code in table.column(axis).to_pylist()]
            table = table.append_column(f"{axis}_order", pa.array(values, type=pa.int32()))
    return table


def cache_path(group: str, spec: dict) -> Path:
    # YAML で引用符を落とすと updated_date が date になるので、文字列に揃える
    return CACHE_DIR / group / f"{spec['name']}.{spec['updated_date']}.parquet"


def fetch(app_id: str, group: str, spec: dict, keep_order: bool = False) -> None:
    out = cache_path(group, spec)
    if out.exists():
        logger.info(f"  {spec['name']}: 取得済み")
        return
    out.parent.mkdir(parents=True, exist_ok=True)
    resource = estat_table(stats_data_id=spec["stats_data_id"], app_id=app_id, timeout=300)
    pages, updated = [], set()
    for page in resource:
        # stat_inf は全行に同じ値が複製されるので、更新日だけ抜いてページごとに落とす
        updated.update(pc.unique(pc.struct_field(page["stat_inf"], "updated_date")).to_pylist())
        pages.append(drop_stat_inf(page))
    if not pages:
        raise RuntimeError(f"{spec['name']}: {spec['stats_data_id']} が 0 行で返った")
    table = pa.concat_tables(pages, promote_options="default")
    if updated != {str(spec["updated_date"])}:
        raise SystemExit(
            f"{spec['name']}: e-Stat の更新日 {sorted(updated)} が local_tables.yml の "
            f"{spec['updated_date']} と違う。yml を直してから取り直す"
        )
    # 書き終えてから名前を付けるので、途中で止まった表は次の回に取り直される
    tmp = out.with_suffix(".parquet.tmp")
    if keep_order:
        table = with_class_order(table, class_order(app_id, spec["stats_data_id"]))
    pq.write_table(table, tmp)
    tmp.rename(out)
    logger.info(f"  {spec['name']}: {table.num_rows} 行")


def cached_resource(group: str, spec: dict):
    path = cache_path(group, spec)
    if not path.exists():
        raise SystemExit(f"{path} が無い。先に fetch を回す (local_tables.yml の updated_date で取得したもの)")

    @dlt.resource(
        name=spec["name"],
        write_disposition="replace",
        # 全国の行の保険者名のように NULL の入る列は主キーにできないので、無いグループもある
        primary_key=spec.get("primary_key"),
        # estat_table と同じ契約。列の型が変わったら黙って広げずに落とす
        schema_contract={"tables": "evolve", "columns": "evolve", "data_type": "freeze"},
    )
    def rows():
        yield pq.read_table(path)

    return rows


def main():
    args = sys.argv[1:]
    if len(args) != 2 or args[0] not in ("fetch", "load"):
        raise SystemExit(f"使い方: load_local.py fetch|load <group> (受け取った引数: {args})")
    command, group = args
    spec = load_group(group)

    if command == "fetch":
        app_id = os.environ["ESTAT_API_KEY"]
        if "fetcher" in spec:
            # e-Stat のデータベースに無く、統計表ファイルで配られる統計。
            # pipelines/<fetcher>.py の fetch_local が表ごとの Parquet を書く
            module = importlib.import_module(f"pipelines.{spec['fetcher']}")
            module.fetch_local(app_id, spec, lambda t: cache_path(group, t))
            return
        for table in spec["tables"]:
            fetch(app_id, group, table, keep_order=spec.get("class_order", False))
        return

    # 全部揃っていないと、replace で一部の表だけが新しくなる。ロードより先に揃いを確かめる
    resources = [cached_resource(group, t) for t in spec["tables"]]

    # 宛先から dlt の状態を読み戻さない (load_local_mesh.py と同じ理由。_source の
    # _dlt_pipeline_state が大きく、R2 越しに読むと時間切れになる)。replace で全件を
    # 入れ直すので状態は要らない。CI の estat の状態に混ざらないよう名前も分ける
    os.environ["RESTORE_FROM_DESTINATION"] = "false"
    pipeline = create_pipeline(f"estat_local_{group}")
    info = pipeline.run(resources)
    logger.info(f"  {group}: {info}")
    dbt_build(select=spec["dbt_select"])


if __name__ == "__main__":
    main()
