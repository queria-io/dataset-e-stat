"""国勢調査 小地域(町丁・字等)統計取得 (searchKind=2 + getStatsData)。

小地域統計は getStatsList のデフォルト(searchKind=1)では返らない。searchKind=2
を指定して都道府県別の statsDataId を動的に収集し、各 ID を getStatsData で取得する。
estat_table は 1 ID = 1 リソースのため、apply_hints で出力先テーブル名を揃えて
47 都道府県を 1 テーブルへ merge する。area コードは境界データ small_area の
key_code と同一体系で、key_code = area で結合できる。
"""

import logging
from typing import List, Optional

from estat_api_dlt_helper import estat_source, estat_table
from estat_api_dlt_helper.api.client import EstatApiClient

from pipelines import EstatStatus

# TABLE_INF の COLLECT_AREA 欠落に対応する互換パッチ。import した時点で当たる。
from pipelines import estat_compat  # noqa: F401
from pipelines.ssds import drop_stat_inf

logger = logging.getLogger(__name__)

# 国勢調査(政府統計コード)
CENSUS_STATS_CODE = "00200521"
# 令和2年国勢調査
SURVEY_YEAR = 2020

# 取り込む小地域統計表。title_prefix は統計表名から末尾の都道府県名を除いた接頭辞。
# どの表も次元は cat01(主分類)・cat02(秘匿・合算区分)・area で、primary_key も共通。
SMALL_AREA_TABLES = [
    {
        "name": "census_small_area_age",
        "title_prefix": "年齢（５歳階級、４区分）別、男女別人口",
        "primary_key": ["cat01", "cat02", "area"],
    },
    {
        "name": "census_small_area_household",
        "title_prefix": "世帯の家族類型別一般世帯数",
        "primary_key": ["cat01", "cat02", "area"],
    },
    {
        "name": "census_small_area_industry",
        "title_prefix": "産業（大分類）別及び従業上の地位別就業者数",
        "primary_key": ["cat01", "cat02", "area"],
    },
    {
        "name": "census_small_area_housing",
        "title_prefix": "住宅の所有の関係別一般世帯数",
        "primary_key": ["cat01", "cat02", "area"],
    },
    {
        "name": "census_small_area_household_size",
        "title_prefix": "世帯人員別一般世帯数",
        "primary_key": ["cat01", "cat02", "area"],
    },
    {
        "name": "census_small_area_building_type",
        "title_prefix": "住宅の建て方別世帯数",
        "primary_key": ["cat01", "cat02", "area"],
    },
    {
        "name": "census_small_area_economic_type",
        "title_prefix": "世帯の経済構成別一般世帯数",
        "primary_key": ["cat01", "cat02", "area"],
    },
]


def fetch_small_area_ids(app_id: str, title_prefix: str) -> List[str]:
    """指定表題の国勢調査小地域統計表 ID を都道府県分収集する。

    Args:
        app_id: e-Stat API アプリケーション ID。
        title_prefix: 統計表名の接頭辞(都道府県名を除いた表題)。
            例: "年齢（５歳階級、４区分）別、男女別人口"

    Returns:
        条件に合致する statsDataId のリスト(通常 47 件)。
    """
    client = EstatApiClient(app_id=app_id, timeout=300)
    result = client.get_stats_list(
        statsCode=CENSUS_STATS_CODE,
        searchKind=2,
        surveyYears=SURVEY_YEAR,
    )
    stats_list = result.get("GET_STATS_LIST", {})
    status = stats_list.get("RESULT", {}).get("STATUS")
    if status not in (EstatStatus.OK, EstatStatus.PARTIAL):
        error_msg = stats_list.get("RESULT", {}).get("ERROR_MSG", "Unknown error")
        raise RuntimeError(f"small_area: API error (status {status}): {error_msg}")

    tables = stats_list.get("DATALIST_INF", {}).get("TABLE_INF", [])
    if isinstance(tables, dict):
        tables = [tables]

    ids: List[str] = []
    for t in tables:
        if str(t.get("SMALL_AREA")) != "1":
            continue
        title = t.get("TITLE")
        if isinstance(title, dict):
            title = title.get("$")
        if title and str(title).startswith(title_prefix):
            ids.append(t["@id"])

    logger.info(f"small_area: {len(ids)} tables for '{title_prefix}'")
    return ids


def create_small_area_source(
    app_id: str,
    stats_data_ids: List[str],
    table_name: str,
    primary_key: List[str],
    maximum_offset: Optional[int] = None,
):
    """複数都道府県の小地域統計表を 1 テーブルへ集約するソースを作成する。

    各 statsDataId を個別リソースとして取得し、apply_hints で出力先テーブル名を
    揃えることで 1 テーブルへ merge する。primary_key に area を含めるため
    都道府県をまたいで行が重複することはない。

    stat_inf は SSDS と同様に除去する。census_small_area_age (47都道府県で
    1000万行超) では stat_inf を含んだままだと merge SQL が GitHub ランナーの
    DuckDB memory_limit (約12.4GiB) を超えて OOM になる。
    """
    resources = []
    for sid in stats_data_ids:
        resource = estat_table(
            stats_data_id=sid,
            app_id=app_id,
            table_name=f"_sa_{sid}",
            write_disposition="merge",
            primary_key=primary_key,
            maximum_offset=maximum_offset,
        )
        resource.add_map(drop_stat_inf)
        resource.apply_hints(table_name=table_name)
        resources.append(resource)
    return estat_source(tables=resources, app_id=app_id)
