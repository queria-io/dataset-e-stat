"""e-Stat データパイプライン。

1. census_boundary:    国勢調査境界データ取得 (Shapefile DL)
2. mesh_boundary:      1kmメッシュ境界データ取得 (統計GIS GML DL)
3. municipality_code:  統計に用いる標準地域コード取得 (総務省統計局 CSV/Excel DL)
4. industry_code:      日本標準産業分類取得 (e-Stat 統計分類 CSV DL)
5. stats_list:         統計表カタログ取得 (getStatsList)
6. meta_info:          メタ情報取得 (getMetaInfo) — 直近更新分のみ
7. ssds:               社会・人口統計体系データ取得 (getStatsData)
8. census_small_area:  国勢調査小地域(町丁・字等)統計取得 (searchKind=2 + getStatsData)
9. mesh_stats:         1kmメッシュ統計取得 (searchKind=2 + getStatsData)
10. census_municipality: 国勢調査 市区町村・都道府県別 基本集計取得 (getStatsData)
11. resident_registry: 住民基本台帳 人口・世帯数・人口動態取得 (getDataCatalog + Excel DL)
12. economic_census:   経済センサス‐活動調査 産業横断的集計取得 (getStatsData)
13. census_commuting:  国勢調査 従業地・通学地集計取得 (getStatsData)
14. manufacture:       工業統計調査 市区町村別・産業中分類別統計取得 (getStatsData)
15. local_finance:     地方財政状況調査 決算収支・財政力取得 (getDataCatalog + CSV DL)
16. welfare_facility:  社会福祉施設等調査 施設数・定員・在所者数・従事者数取得 (getDataCatalog + CSV DL)
17. kaigo_service:     介護サービス施設・事業所調査 介護保険施設数・定員・事業所数取得 (getDataCatalog + CSV DL)
18. wage_structure:    賃金構造基本統計調査 都道府県別・産業別の賃金取得 (getDataCatalog + Excel DL)
19. school:            学校基本調査 小学校・中学校の学年別児童生徒数取得 (getDataCatalog + Excel DL)
20. school_health:     学校保健統計調査 都道府県別の身長・体重取得 (getDataCatalog + Excel DL)
21. crop:              作物統計調査 野菜の都道府県別の収穫量・出荷量取得 (getStatsList + getStatsData)
22. construction_orders: 建設工事受注動態統計調査 公共工事の発注機関別・施工都道府県別請負契約額取得 (getDataCatalog + Excel DL)
23. trade:             普通貿易統計 品別国別表の新しい年の分を取得 (getDataCatalog + CSV DL)
24. commerce:          商業動態統計調査 業種別商業販売額の時系列を取得 (getDataCatalog + Excel DL)
25. production:        経済産業省生産動態統計 月報の統計表を取得 (getDataCatalog + Excel DL)
26. dbt:               dbt ビルド

250mメッシュ統計はここでは取り込まない。量が多く CI のメモリに収まらないので、
手元で load_local_mesh.py を回してロードする (README「手元でだけ取り込むテーブル」)。
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
from pipelines.commerce import build_commerce_sales
from pipelines.construction_orders import build_construction_orders
from pipelines.crop import build_crop
from pipelines.economic_census import (
    ECONOMIC_CENSUS_TABLES,
    create_economic_census_source,
    fetch_economic_census_ids,
)
from pipelines.industry_code import build_industry_code
from pipelines.kaigo_service import build_kaigo_service
from pipelines.local_finance import build_local_finance
from pipelines.manufacture import (
    create_manufacture_source,
    fetch_manufacture_ids,
)
from pipelines.mesh_boundary import download_mesh_boundary
from pipelines.mesh_stats import (
    MESH_STATS_TABLES,
    create_mesh_source,
    fetch_mesh_ids,
)
from pipelines.meta_info import meta_info_resource
from pipelines.municipality_code import build_municipality_code
from pipelines.production import build_production
from pipelines.resident_registry import build_resident_registry
from pipelines.school import build_school
from pipelines.school_health import build_school_health
from pipelines.ssds import create_source
from pipelines.stats_list import fetch_updated_ids, stats_list_resource
from pipelines.trade import build_trade_recent
from pipelines.wage_structure import build_wage_structure
from pipelines.welfare_facility import build_welfare_facility

logger = logging.getLogger("pipelines")


def dbt_build(select: str | None = None):
    """dbt をビルドする。select を渡すとそのノードだけをビルドする。

    docs generate は公開に要る catalog.json を作るので、select の有無によらず回す。
    """
    dbt = dbtRunner()

    result = dbt.invoke(["deps"])
    if not result.success:
        raise SystemExit("dbt deps failed")

    result = dbt.invoke(["build"] + (["--select", select] if select else []))
    if not result.success:
        raise SystemExit("dbt build failed")

    result = dbt.invoke(["docs", "generate"])
    if not result.success:
        raise SystemExit("dbt docs generate failed")


def main():
    with open(Path(__file__).parent / "tables.yml") as f:
        tables_config = yaml.safe_load(f)

    # 1. 国勢調査境界データ (Shapefile DL)
    logger.info("1/26: census_boundary (国勢調査境界データ)")
    download_boundary("data/census_boundary")

    # 2. 1kmメッシュ境界データ (統計GIS GML DL、API 不要)
    logger.info("2/26: mesh_boundary (1kmメッシュ境界データ)")
    download_mesh_boundary("data/mesh_boundary")

    # 3. 統計に用いる標準地域コード (総務省統計局 CSV/Excel DL、API 不要)
    logger.info("3/26: municipality_code (統計に用いる標準地域コード)")
    build_municipality_code("data/municipality_code")

    # 4. 日本標準産業分類 (e-Stat 統計分類 CSV DL、API 不要)
    logger.info("4/26: industry_code (日本標準産業分類)")
    build_industry_code("data/industry_code")

    pipeline = create_pipeline()
    app_id = os.environ["ESTAT_API_KEY"]

    # 5. 統計表カタログ (全件取得)
    logger.info("5/26: stats_list (統計表カタログ)")
    info = pipeline.run(stats_list_resource(app_id))
    logger.info(f"  {info}")

    # 6. メタ情報 (直近3日間に更新された統計表のみ)
    logger.info("6/26: meta_info (メタ情報)")
    updated_ids = fetch_updated_ids(app_id, days=3)
    if updated_ids:
        info = pipeline.run(meta_info_resource(app_id, updated_ids))
        logger.info(f"  {info}")
    else:
        logger.info("  skip (no updates)")

    # 7. 社会・人口統計体系(SSDS) データ
    logger.info("7/26: ssds (社会・人口統計体系)")
    info = pipeline.run(create_source(app_id, tables_config))
    logger.info(f"  {info}")

    # 8. 国勢調査 小地域(町丁・字等)統計データ
    logger.info("8/26: census_small_area (小地域統計)")
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

    # 9. 国勢調査・経済センサス 1kmメッシュ統計データ
    logger.info("9/26: mesh_stats (1kmメッシュ統計)")
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

    # 10. 国勢調査 市区町村・都道府県別 基本集計
    logger.info("10/26: census_municipality (市区町村・都道府県別 基本集計)")
    ids = fetch_municipality_ids(app_id, MUNICIPALITY_TABLES)
    info = pipeline.run(create_municipality_source(app_id, ids))
    logger.info(f"  {info}")

    # 11. 住民基本台帳に基づく人口・世帯数・人口動態
    logger.info("11/26: resident_registry (住民基本台帳 人口・世帯数・人口動態)")
    build_resident_registry("data/resident_registry", app_id)

    # 12. 経済センサス‐活動調査 産業横断的集計
    logger.info("12/26: economic_census (経済センサス 産業横断的集計)")
    ids = fetch_economic_census_ids(app_id, ECONOMIC_CENSUS_TABLES)
    info = pipeline.run(create_economic_census_source(app_id, ids))
    logger.info(f"  {info}")

    # 13. 国勢調査 従業地・通学地による人口・就業状態等集計
    logger.info("13/26: census_commuting (従業地・通学地集計)")
    ids = fetch_municipality_ids(app_id, COMMUTING_TABLES, context="census_commuting")
    info = pipeline.run(create_commuting_source(app_id, ids))
    logger.info(f"  {info}")

    # 14. 工業統計調査 市区町村別、産業中分類別統計
    logger.info("14/26: manufacture (工業統計調査 市区町村別・産業中分類別)")
    manufacture_ids = fetch_manufacture_ids(app_id)
    info = pipeline.run(create_manufacture_source(app_id, manufacture_ids))
    logger.info(f"  {info}")

    # 15. 地方財政状況調査 決算収支・財政力
    logger.info("15/26: local_finance (地方財政状況調査)")
    build_local_finance("data/local_finance", app_id)

    # 16. 社会福祉施設等調査 施設数・定員・在所者数・従事者数
    logger.info("16/26: welfare_facility (社会福祉施設等調査)")
    build_welfare_facility("data/welfare_facility", app_id)

    # 17. 介護サービス施設・事業所調査 介護保険施設数・定員・居宅サービス等の事業所数
    logger.info("17/26: kaigo_service (介護サービス施設・事業所調査)")
    build_kaigo_service("data/kaigo_service", app_id)

    # 18. 賃金構造基本統計調査 都道府県別・産業別の賃金
    logger.info("18/26: wage_structure (賃金構造基本統計調査)")
    build_wage_structure("data/wage_structure", app_id)

    # 19. 学校基本調査 小学校・中学校の学年別児童生徒数
    logger.info("19/26: school (学校基本調査)")
    build_school("data/school", app_id)

    # 20. 学校保健統計調査 都道府県別の身長・体重
    logger.info("20/26: school_health (学校保健統計調査)")
    build_school_health("data/school_health", app_id)

    # 21. 作物統計調査 野菜の都道府県別 (getStatsList + getStatsData)
    logger.info("21/26: crop (作物統計調査 野菜)")
    build_crop("data/crop", app_id)

    # 22. 建設工事受注動態統計調査 公共工事の発注機関別・施工都道府県別請負契約額
    logger.info("22/26: construction_orders (建設工事受注動態統計調査 公共工事)")
    build_construction_orders("data/construction_orders", app_id)

    # 23. 普通貿易統計 品別国別表のうち、手元で取り込んだ年 (local_tables.yml の trade グループの
    # through_year) より後の年。年の途中は毎月データセットが差し替わり、確報で前の月も直るので、
    # 毎回取り直して置き換える
    logger.info("23/26: trade (普通貿易統計 品別国別表 新しい年)")
    with open(Path(__file__).parent / "local_tables.yml") as f:
        trade_group = yaml.safe_load(f)["groups"]["trade"]
    build_trade_recent("data/trade", app_id, int(trade_group["catalog_filter"]["through_year"]))

    # 24. 商業動態統計調査 業種別商業販売額。全期間が 1 つの Excel (約 0.4MB) で、毎月の公表で
    # 過去の月も直るので、毎回取り直して置き換える
    logger.info("24/26: commerce (商業動態統計調査 業種別商業販売額)")
    build_commerce_sales("data/commerce", app_id)

    # 25. 経済産業省生産動態統計 月報の統計表（2022年から）。年ごとに最新の月のファイルを取り直す
    logger.info("25/26: production (経済産業省生産動態統計)")
    build_production("data/production", app_id)

    # 26. dbt ビルド
    logger.info("26/26: dbt build")
    dbt_build()


if __name__ == "__main__":
    main()
