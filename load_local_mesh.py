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

import logging
import os
import sys
from pathlib import Path

import dlt
import pyarrow as pa
import pyarrow.parquet as pq
from dbt.cli.main import dbtRunner
from estat_api_dlt_helper import estat_table

from pipelines import create_pipeline
from pipelines.mesh_stats import LOCAL_MESH_STATS_TABLES, fetch_mesh_ids
from pipelines.ssds import drop_stat_inf

logger = logging.getLogger("pipelines")

CACHE_DIR = Path("data/mesh")


def fetch(app_id: str, spec: dict) -> None:
    """統計表を 1 次メッシュの表ごとに CACHE_DIR/<name>/<id>.parquet へ保存する。"""
    out = CACHE_DIR / spec["name"]
    out.mkdir(parents=True, exist_ok=True)
    ids = fetch_mesh_ids(app_id, spec["stats_code"], spec["statistics_name"], spec["table_name"])
    todo = [sid for sid in ids if not (out / f"{sid}.parquet").exists()]
    logger.info(f"  {spec['name']}: {len(ids)} 表、未取得 {len(todo)}")
    for i, sid in enumerate(todo, 1):
        resource = estat_table(stats_data_id=sid, app_id=app_id, timeout=300).add_map(drop_stat_inf)
        table = pa.concat_tables(list(resource), promote_options="default")
        # 書き終えてから名前を付けるので、途中で止まった表は次の回に取り直される
        tmp = out / f"{sid}.parquet.tmp"
        pq.write_table(table, tmp)
        tmp.rename(out / f"{sid}.parquet")
        logger.info(f"  [{i}/{len(todo)}] {sid}: {table.num_rows} 行")


def cached_resource(spec: dict):
    files = sorted((CACHE_DIR / spec["name"]).glob("*.parquet"))
    if not files:
        raise SystemExit(f"{CACHE_DIR / spec['name']} に Parquet が無い。先に fetch を回す")

    @dlt.resource(
        name=spec["name"],
        write_disposition=spec["write_disposition"],
        primary_key=spec["primary_key"],
    )
    def rows():
        for f in files:
            yield pq.read_table(f)

    return rows


def dbt_build_mesh() -> None:
    """250m のモデルとその下流だけをビルドする。docs generate は公開に要る catalog.json を作る。"""
    dbt = dbtRunner()
    for cmd in (["deps"], ["build", "--select", "raw_mesh_population_250m+"], ["docs", "generate"]):
        if not dbt.invoke(cmd).success:
            raise SystemExit(f"dbt {cmd[0]} failed")


def main():
    if sys.argv[1:] == ["fetch"]:
        app_id = os.environ["ESTAT_API_KEY"]
        for spec in LOCAL_MESH_STATS_TABLES:
            fetch(app_id, spec)
        return

    pipeline = create_pipeline()
    for spec in LOCAL_MESH_STATS_TABLES:
        info = pipeline.run(cached_resource(spec))
        logger.info(f"  {spec['name']}: {info}")
    dbt_build_mesh()


if __name__ == "__main__":
    main()
