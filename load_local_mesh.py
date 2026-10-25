"""手元でだけ取り込むメッシュ統計 (250mメッシュ) をロードし、dbt をビルドする。

CI の main.py では扱わない。量が多く GitHub ランナーのメモリに収まらないため。
令和2年国勢調査の値は次の調査まで変わらないので、カタログを作り直したときなどに
手元で一度回せばよい。手順は README の「手元でだけ取り込むテーブル」を参照。

取得と公開を分ける。取得は 2〜3 時間かかり、その間に CI の Sync が公開すると、
sync の push は公開済みのカタログが変わったとして断られる。取得をカタログの外で
済ませておけば、sync の中はファイルのロードと 250m の dbt だけで数分になる。

    uv run --env-file .env python load_local_mesh.py fetch     # 取得 (data/mesh/ に保存)
    uv run queria sync -- uv run --env-file .env python load_local_mesh.py

fetch は 1 次メッシュの表ごとに Parquet を書き、書き終えた表は次から飛ばすので、
途中で止まっても続きから回せる。
"""

import json
import logging
import os
import sys
from pathlib import Path

import dlt
import pyarrow as pa
import pyarrow.parquet as pq
from estat_api_dlt_helper import estat_table

from main import dbt_build
from pipelines import create_pipeline
from pipelines.mesh_stats import LOCAL_MESH_STATS_TABLES, fetch_mesh_ids
from pipelines.ssds import drop_stat_inf

logger = logging.getLogger("pipelines")

# 置き場所を作業ディレクトリによらず固定する。別の場所から fetch すると、
# ロードの側からは見えないところに保存されてしまう
CACHE_DIR = Path(__file__).parent / "data" / "mesh"

# fetch が集めた統計表 ID の一覧。ロードはこれに載った表だけを、全部揃っているときにだけ読む
IDS_FILE = "ids.json"


def fetch(app_id: str, spec: dict) -> None:
    """統計表を 1 次メッシュの表ごとに CACHE_DIR/<name>/<id>.parquet へ保存する。"""
    out = CACHE_DIR / spec["name"]
    out.mkdir(parents=True, exist_ok=True)
    ids = fetch_mesh_ids(app_id, spec["stats_code"], spec["statistics_name"], spec["table_name"])
    (out / IDS_FILE).write_text(json.dumps(ids))
    todo = [sid for sid in ids if not (out / f"{sid}.parquet").exists()]
    logger.info(f"  {spec['name']}: {len(ids)} 表、未取得 {len(todo)}")
    for i, sid in enumerate(todo, 1):
        resource = estat_table(stats_data_id=sid, app_id=app_id, timeout=300).add_map(drop_stat_inf)
        pages = list(resource)
        if not pages:
            raise RuntimeError(f"{spec['name']}: {sid} が 0 行で返った")
        table = pa.concat_tables(pages, promote_options="default")
        # 書き終えてから名前を付けるので、途中で止まった表は次の回に取り直される
        tmp = out / f"{sid}.parquet.tmp"
        pq.write_table(table, tmp)
        tmp.rename(out / f"{sid}.parquet")
        logger.info(f"  [{i}/{len(todo)}] {sid}: {table.num_rows} 行")


def cached_resource(spec: dict):
    out = CACHE_DIR / spec["name"]
    if not (out / IDS_FILE).exists():
        raise SystemExit(f"{out / IDS_FILE} が無い。先に fetch を回す")
    ids = json.loads((out / IDS_FILE).read_text())
    files = [out / f"{sid}.parquet" for sid in ids]
    # replace で書くので、欠けたまま読むと前回ロードした全量が一部で置き換わる
    missing = [f.name for f in files if not f.exists()]
    if missing:
        raise SystemExit(
            f"{out} に {len(ids)} 表のうち {len(missing)} 表が無い。fetch を回し直す"
        )

    @dlt.resource(
        name=spec["name"],
        write_disposition=spec["write_disposition"],
        primary_key=spec["primary_key"],
        # estat_table と同じ契約。列の型が表によって変わったら黙って広げずに落とす
        schema_contract={"tables": "evolve", "columns": "evolve", "data_type": "freeze"},
    )
    def rows():
        for f in files:
            yield pq.read_table(f)

    return rows


def main():
    args = sys.argv[1:]
    if args not in ([], ["fetch"]):
        raise SystemExit(f"使い方: load_local_mesh.py [fetch] (受け取った引数: {args})")

    if args == ["fetch"]:
        app_id = os.environ["ESTAT_API_KEY"]
        for spec in LOCAL_MESH_STATS_TABLES:
            fetch(app_id, spec)
        return

    # 宛先から dlt の状態を読み戻さない。_source._dlt_pipeline_state は CI の実行ごとに
    # 大きな行が積もり (2026-10 時点で 60 ファイル・約 2GB)、手元から R2 越しに読むと
    # タイムアウトする。replace で全件を入れ直すので状態は要らない。CI の estat の
    # スキーマと状態に混ざらないよう、パイプライン名も分ける
    os.environ["RESTORE_FROM_DESTINATION"] = "false"
    pipeline = create_pipeline("estat_mesh_local")
    for spec in LOCAL_MESH_STATS_TABLES:
        info = pipeline.run(cached_resource(spec))
        logger.info(f"  {spec['name']}: {info}")
    # 250m のモデルとその下流 (テストを含む) だけをビルドする
    dbt_build(select="raw_mesh_population_250m+")


if __name__ == "__main__":
    main()
