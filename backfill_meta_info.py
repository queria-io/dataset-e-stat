"""全統計表の getMetaInfo バックフィルスクリプト。

e-Stat の全統計表 (~23万件) に対して getMetaInfo API を呼び、
全分類軸のメタデータを meta_info テーブルにロードする。

meta_info は write_disposition="merge" のため、中断して再実行しても
既存データは保持される。

使い方:
    FDL_TOKEN=... scripts/build.sh --env-file .env python backfill_meta_info.py
"""

import logging
import os

from pipelines import create_pipeline
from pipelines.meta_info import meta_info_resource
from pipelines.stats_list import fetch_all_ids

logging.basicConfig(level=logging.INFO)

# @dlt.defer の並列数を環境変数で設定
os.environ.setdefault("EXTRACT__WORKERS", "10")


def main():
    app_id = os.environ["ESTAT_API_KEY"]
    pipeline = create_pipeline()

    logging.info("Fetching all statsDataIds...")
    all_ids = fetch_all_ids(app_id, cache_ttl_hours=24)
    workers = os.environ.get("EXTRACT__WORKERS", "5")
    logging.info(
        f"Total: {len(all_ids)} unique tables. Starting backfill with {workers} workers..."
    )

    pipeline.run(meta_info_resource(app_id=app_id, stats_data_ids=all_ids))
    logging.info("Backfill complete")


if __name__ == "__main__":
    main()
