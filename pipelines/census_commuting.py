"""国勢調査 従業地・通学地による人口・就業状態等集計の取得 (getStatsData)。

基本集計 (census_municipality) が「どこに住んでいるか」だけを見るのに対し、
この集計は「どこに住む人がどこへ従業・通学しているか」を見る。昼夜間人口と
市区町村間の通勤・通学流動はこの集計にしか無い。

統計表 ID の引き方は基本集計と同じ (TITLE の @no と STATISTICS_NAME) なので、
census_municipality.fetch_municipality_ids をそのまま使う。

■ 取り込む 2 表

1-1-1 は常住地・従業地・通学地の別に人口を出した表で、昼夜間人口の一次データ。
6-1 は常住市区町村 × 従業・通学地の通勤者・通学者数、つまり OD (起終点) 行列。

昼夜間人口比率の 1-1-2 は取らない。14.7 万行のうち値が入るのは男女総数・年齢総数の
1,965 行だけで (年齢階級別と男女別は全行「-」)、その 1,965 行も 1-1-1 の
昼間人口 / 夜間人口 × 100 と一致する。実測: 千代田区 903,780 / 66,680 × 100 =
1355.39892 で公表値と同値。

■ 1-1-1 は年齢の総数だけ取る

男女 3 × 年齢 25 × 常住地従業地 19 × 地域 1,965 で 280 万行あるが、公開するのは
年齢を集計した値なので cdCat02="00" (年齢総数) で絞って取る。年齢階級別を公開する
ときはこの絞り込みを外す。

■ 6-1 は従業・通学地を都道府県までに絞る

6-1 は 常住地 1,965 × 従業・通学地 1,967 × 男女 3 = 1,159 万行あり、うち 86% は
値が「-」の空セルになる (市区町村どうしの通勤・通学は大半が 0 人)。1 回の取得に
100,000 行ずつ 116 リクエスト・実測 21 秒/回 = 約 40 分かかり、毎日走る CI には
重すぎる。lvCat02="1-2" で従業・通学地を「総数」と都道府県 (と「不詳・外国」
「不詳」) に絞ると 29.5 万行・3 リクエストで済み、常住地は市区町村のまま残る。
市区町村どうしの OD を公開するときは取得の分割を設計してからこの絞り込みを外す。
"""

import logging
from typing import Any, Dict, List

from estat_api_dlt_helper import estat_source, estat_table

from pipelines.ssds import drop_stat_inf

logger = logging.getLogger(__name__)

# 従業地・通学地による人口・就業状態等集計
TABULATION = "従業地・通学地による人口・就業状態等集計"

COMMUTING_TABLES: List[Dict[str, Any]] = [
    {
        "name": "census_municipality_daytime_population",
        "tabulation": TABULATION,
        "table_no": "1-1-1",
        "primary_key": ["cat01", "cat03", "area"],
        "api_params": {"cdCat02": "00"},
    },
    {
        "name": "census_commuting_flow",
        "tabulation": TABULATION,
        "table_no": "6-1",
        "primary_key": ["cat01", "cat02", "area"],
        "api_params": {"lvCat02": "1-2"},
    },
]


def create_commuting_source(app_id: str, ids: Dict[str, str]):
    """従業地・通学地集計のソースを作成する。

    stat_inf は SSDS・小地域・基本集計と同様に除去する。統計表単位のメタ情報が
    全行に複製される冗長な列で、stg / mart からは参照しない。
    """
    resources = []
    for spec in COMMUTING_TABLES:
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
