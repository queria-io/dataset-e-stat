"""手元でだけ取り込むメッシュ統計 (250mメッシュ) をロードし、dbt をビルドする。

CI の main.py では扱わない。量が多く GitHub ランナーのメモリに収まらないため。
令和2年国勢調査の値は次の調査まで変わらないので、カタログを作り直したときなどに
手元で一度回せばよい。手順は README の「手元でだけ取り込むテーブル」を参照。

    uv run queria sync -- uv run --env-file .env python load_local_mesh.py
"""

import logging
import os

from main import dbt_build
from pipelines import create_pipeline
from pipelines.mesh_stats import LOCAL_MESH_STATS_TABLES, create_mesh_source, fetch_mesh_ids

logger = logging.getLogger("pipelines")


def main():
    pipeline = create_pipeline()
    app_id = os.environ["ESTAT_API_KEY"]

    for spec in LOCAL_MESH_STATS_TABLES:
        ids = fetch_mesh_ids(app_id, spec["stats_code"], spec["statistics_name"], spec["table_name"])
        info = pipeline.run(
            create_mesh_source(
                app_id,
                ids,
                spec["name"],
                spec["primary_key"],
                write_disposition=spec["write_disposition"],
            )
        )
        logger.info(f"  {spec['name']}: {info}")

    dbt_build()


if __name__ == "__main__":
    main()
