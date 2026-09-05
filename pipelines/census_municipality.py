"""国勢調査 市区町村・都道府県別 基本集計の取得 (getStatsData)。

小地域・メッシュ統計と違い searchKind=1 の通常の統計表なので、統計表 ID は
政府統計コード・調査年・統計表番号 (TITLE の @no) で引ける。

■ 表を @no と集計の種類で引く理由

同じ @no の表が複数の集計 (人口等基本集計・就業状態等基本集計・不詳補完結果・
時系列データ) にあるため、STATISTICS_NAME に集計の名前を含むことを併せて条件に
する。これを外すと 1-1-1 だけで 5 つ、1-2-1 で 3 つの ID が当たる。

また getStatsList のレスポンスには同一 @id が複数回現れる (令和2年国勢調査で
1,747 行・632 ID)。ID は集合として扱い、1 件に定まらなければ落とす。

■ 人口等基本集計の 3 表を 1 つの mart にまとめる

1-1-1 (男女別人口)・1-1-2 (世帯の種類別世帯数及び世帯人員)・1-1-3 (人口増減・
面積・人口密度) は area の分類が完全に一致する (4,086 地域)。測定項目が表ごとに
固定なので、mart では地域 1 行の横持ちに直す。

■ 就業状態等基本集計は年齢の総数だけ取る

1-2-1 は男女 3 × 年齢 23 × 労働力状態 13 × 地域 1,965 で 176 万行あるが、
公開するのは年齢を集計した値なので cdCat02="00" (年齢総数) で絞って取る。
毎日走る CI で 176 万行を取り直しても、捨てる行が 96% を占める。
年齢階級別を公開するときはこの絞り込みを外す。
"""

import logging
from typing import Any, Dict, List

from estat_api_dlt_helper import estat_source, estat_table
from estat_api_dlt_helper.api.client import EstatApiClient

from pipelines import EstatStatus
from pipelines.ssds import drop_stat_inf

logger = logging.getLogger(__name__)

# 国勢調査(政府統計コード)
CENSUS_STATS_CODE = "00200521"
# 令和2年国勢調査
SURVEY_YEAR = 2020

# 取り込む統計表。table_no は TITLE の @no、tabulation は STATISTICS_NAME に
# 含まれる集計の名前。api_params は getStatsData に渡す追加の絞り込み。
MUNICIPALITY_TABLES: List[Dict[str, Any]] = [
    {
        "name": "census_municipality_population",
        "tabulation": "人口等基本集計",
        "table_no": "1-1-1",
        "primary_key": ["cat01", "area"],
    },
    {
        "name": "census_municipality_household",
        "tabulation": "人口等基本集計",
        "table_no": "1-1-2",
        "primary_key": ["tab", "cat01", "area"],
    },
    {
        "name": "census_municipality_change",
        "tabulation": "人口等基本集計",
        "table_no": "1-1-3",
        "primary_key": ["tab", "area"],
    },
    {
        "name": "census_municipality_labor_force",
        "tabulation": "就業状態等基本集計",
        "table_no": "1-2-1",
        "primary_key": ["cat01", "cat02", "cat03", "area"],
        "api_params": {"cdCat02": "00"},
    },
    {
        "name": "census_municipality_employment_status",
        "tabulation": "就業状態等基本集計",
        "table_no": "3-2",
        "primary_key": ["cat01", "cat02", "area"],
    },
]


def fetch_municipality_ids(
    app_id: str, specs: List[Dict[str, Any]], context: str = "census_municipality"
) -> Dict[str, str]:
    """統計表番号と集計の種類から statsDataId を引く。

    国勢調査の統計表はどの集計でも TITLE の @no と STATISTICS_NAME で引けるので、
    従業地・通学地集計 (census_commuting) もこの関数を使う。

    Args:
        app_id: e-Stat API アプリケーション ID。
        specs: MUNICIPALITY_TABLES と同じ形の要素。table_no と tabulation を見る。
        context: エラーメッセージに出す呼び出し元の名前。

    Returns:
        テーブル名 -> statsDataId の対応。

    Raises:
        RuntimeError: API がエラーを返したとき、および統計表番号が 1 件に
            定まらなかったとき。0 件を握り潰すと、e-Stat 側の表番号が変わっても
            dbt は前回ロード済みの _source でビルドに成功し、CI が緑のまま
            テーブルが更新されなくなる。
    """
    client = EstatApiClient(app_id=app_id, timeout=300)
    result = client.get_stats_list(
        statsCode=CENSUS_STATS_CODE, surveyYears=SURVEY_YEAR, limit=100000
    )

    stats_list = result.get("GET_STATS_LIST", {})
    status = stats_list.get("RESULT", {}).get("STATUS")
    if status not in (EstatStatus.OK, EstatStatus.PARTIAL):
        error_msg = stats_list.get("RESULT", {}).get("ERROR_MSG", "Unknown error")
        raise RuntimeError(f"{context}: API error (status {status}): {error_msg}")

    tables = stats_list.get("DATALIST_INF", {}).get("TABLE_INF", [])
    if isinstance(tables, dict):
        tables = [tables]

    resolved: Dict[str, str] = {}
    for spec in specs:
        no = spec["table_no"]
        tabulation = spec["tabulation"]
        ids = {
            t["@id"]
            for t in tables
            if isinstance(t.get("TITLE"), dict)
            and t["TITLE"].get("@no") == no
            and tabulation in str(t.get("STATISTICS_NAME") or "")
        }
        if len(ids) != 1:
            raise RuntimeError(
                f"{context}: table_no={no} tabulation={tabulation} "
                f"matched {len(ids)} ids ({sorted(ids)}) in "
                f"statsCode={CENSUS_STATS_CODE} surveyYears={SURVEY_YEAR} "
                f"({len(tables)} rows scanned). "
                "e-Stat 側の表番号が変わった可能性がある。"
                "取り込む統計表の一覧を確認する。"
            )
        resolved[spec["name"]] = ids.pop()

    logger.info(f"{context}: resolved {resolved}")
    return resolved


def create_municipality_source(app_id: str, ids: Dict[str, str]):
    """市区町村・都道府県別 基本集計のソースを作成する。

    stat_inf は SSDS・小地域と同様に除去する。統計表単位のメタ情報が全行に
    複製される冗長な列で、stg / mart からは参照しない。
    """
    resources = []
    for spec in MUNICIPALITY_TABLES:
        resource = estat_table(
            stats_data_id=ids[spec["name"]],
            app_id=app_id,
            table_name=spec["name"],
            write_disposition="merge",
            primary_key=spec["primary_key"],
            **spec.get("api_params", {}),
        )
        resource.add_map(drop_stat_inf)
        resources.append(resource)
    return estat_source(tables=resources, app_id=app_id)
