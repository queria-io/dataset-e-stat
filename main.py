"""e-Stat データパイプライン。

1. census_boundary:    国勢調査境界データ取得 (Shapefile DL)
2. mesh_boundary:      1kmメッシュ境界データ取得 (統計GIS GML DL)
3. municipality_code:  統計に用いる標準地域コード取得 (総務省統計局 CSV/Excel DL)
4. stats_list:         統計表カタログ取得 (getStatsList)
5. meta_info:          メタ情報取得 (getMetaInfo) — 直近更新分のみ
6. ssds:               社会・人口統計体系データ取得 (getStatsData)
7. census_small_area:  国勢調査小地域(町丁・字等)統計取得 (searchKind=2 + getStatsData)
8. mesh_stats:         1kmメッシュ統計取得 (searchKind=2 + getStatsData)
9. census_municipality: 国勢調査 市区町村・都道府県別 基本集計取得 (getStatsData)
10. resident_registry: 住民基本台帳 人口・世帯数・人口動態取得 (getDataCatalog + Excel DL)
11. economic_census:   経済センサス‐活動調査 産業横断的集計取得 (getStatsData)
12. census_commuting:  国勢調査 従業地・通学地集計取得 (getStatsData)
13. dbt:               dbt ビルド
"""

import logging
import os
from pathlib import Path

import yaml
from dbt.cli.main import dbtRunner

from pipelines import create_pipeline
from pipelines.census_boundary import download_boundary
from pipelines.census_commuting import (
    COMMUTING_TABLES,
    create_commuting_source,
)
from pipelines.census_municipality import (
    MUNICIPALITY_TABLES,
    create_municipality_source,
    fetch_municipality_ids,
)
from pipelines.census_small_area import (
    SMALL_AREA_TABLES,
    create_small_area_source,
    fetch_small_area_ids,
)
from pipelines.economic_census import (
    ECONOMIC_CENSUS_TABLES,
    create_economic_census_source,
    fetch_economic_census_ids,
)
from pipelines.mesh_boundary import download_mesh_boundary
from pipelines.mesh_stats import (
    MESH_STATS_TABLES,
    create_mesh_source,
    fetch_mesh_ids,
)
from pipelines.meta_info import meta_info_resource
from pipelines.municipality_code import build_municipality_code
from pipelines.resident_registry import build_resident_registry
from pipelines.ssds import create_source
from pipelines.stats_list import fetch_updated_ids, stats_list_resource

logger = logging.getLogger("pipelines")


def dbt_build():
    dbt = dbtRunner()

    result = dbt.invoke(["deps"])
    if not result.success:
        raise SystemExit("dbt deps failed")

    result = dbt.invoke(["build"])
    if not result.success:
        raise SystemExit("dbt build failed")

    result = dbt.invoke(["docs", "generate"])
    if not result.success:
        raise SystemExit("dbt docs generate failed")


def main():
    with open(Path(__file__).parent / "tables.yml") as f:
        tables_config = yaml.safe_load(f)

    # 1. 国勢調査境界データ (Shapefile DL)
    logger.info("1/13: census_boundary (国勢調査境界データ)")
    download_boundary("data/census_boundary")

    # 2. 1kmメッシュ境界データ (統計GIS GML DL、API 不要)
    logger.info("2/13: mesh_boundary (1kmメッシュ境界データ)")
    download_mesh_boundary("data/mesh_boundary")

    # 3. 統計に用いる標準地域コード (総務省統計局 CSV/Excel DL、API 不要)
    logger.info("3/13: municipality_code (統計に用いる標準地域コード)")
    build_municipality_code("data/municipality_code")

    pipeline = create_pipeline()
    app_id = os.environ["ESTAT_API_KEY"]

    # 4. 統計表カタログ (全件取得)
    logger.info("4/13: stats_list (統計表カタログ)")
    info = pipeline.run(stats_list_resource(app_id))
    logger.info(f"  {info}")

    # 5. メタ情報 (直近3日間に更新された統計表のみ)
    logger.info("5/13: meta_info (メタ情報)")
    updated_ids = fetch_updated_ids(app_id, days=3)
    if updated_ids:
        info = pipeline.run(meta_info_resource(app_id, updated_ids))
        logger.info(f"  {info}")
    else:
        logger.info("  skip (no updates)")

    # 6. 社会・人口統計体系(SSDS) データ
    logger.info("6/13: ssds (社会・人口統計体系)")
    info = pipeline.run(create_source(app_id, tables_config))
    logger.info(f"  {info}")

    # 7. 国勢調査 小地域(町丁・字等)統計データ
    logger.info("7/13: census_small_area (小地域統計)")
    for spec in SMALL_AREA_TABLES:
        ids = fetch_small_area_ids(app_id, spec["title_prefix"])
        if ids:
            info = pipeline.run(
                create_small_area_source(
                    app_id, ids, spec["name"], spec["primary_key"]
                )
            )
            logger.info(f"  {spec['name']}: {info}")
        else:
            logger.info(f"  skip {spec['name']} (no tables)")

    # 8. 国勢調査・経済センサス 1kmメッシュ統計データ
    logger.info("8/13: mesh_stats (1kmメッシュ統計)")
    # fetch_mesh_ids は 0 件のとき例外を投げる。表題が変わってロードが飛ばされても
    # dbt は前回分でビルドが通ってしまい、CI が緑のままテーブルが更新されなくなるため。
    for spec in MESH_STATS_TABLES:
        ids = fetch_mesh_ids(
            app_id, spec["stats_code"], spec["statistics_name"], spec["table_name"]
        )
        info = pipeline.run(
            create_mesh_source(app_id, ids, spec["name"], spec["primary_key"])
        )
        logger.info(f"  {spec['name']}: {info}")

    # 9. 国勢調査 市区町村・都道府県別 基本集計
    logger.info("9/13: census_municipality (市区町村・都道府県別 基本集計)")
    ids = fetch_municipality_ids(app_id, MUNICIPALITY_TABLES)
    info = pipeline.run(create_municipality_source(app_id, ids))
    logger.info(f"  {info}")

    # 10. 住民基本台帳に基づく人口・世帯数・人口動態
    logger.info("10/13: resident_registry (住民基本台帳 人口・世帯数・人口動態)")
    build_resident_registry("data/resident_registry", app_id)

    # 11. 経済センサス‐活動調査 産業横断的集計
    logger.info("11/13: economic_census (経済センサス 産業横断的集計)")
    ids = fetch_economic_census_ids(app_id, ECONOMIC_CENSUS_TABLES)
    info = pipeline.run(create_economic_census_source(app_id, ids))
    logger.info(f"  {info}")

    # 12. 国勢調査 従業地・通学地による人口・就業状態等集計
    logger.info("12/13: census_commuting (従業地・通学地集計)")
    ids = fetch_municipality_ids(app_id, COMMUTING_TABLES, context="census_commuting")
    info = pipeline.run(create_commuting_source(app_id, ids))
    logger.info(f"  {info}")

    # 13. dbt ビルド
    logger.info("13/13: dbt build")
    dbt_build()


if __name__ == "__main__":
    main()
