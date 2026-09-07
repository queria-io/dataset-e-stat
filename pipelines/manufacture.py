"""工業統計調査 確報 市区町村別・産業中分類別統計の取得 (getStatsData)。

経済センサス‐活動調査 (economic_census) が 5 年に 1 度の全産業の断面なのに対し、
この調査は製造業だけを毎年数える。市区町村 × 産業中分類の製造品出荷額等が
毎年そろうのはこの調査だけで、経済センサスの 2021 年に接続すると製造業の
長期時系列になる。

■ 取り込む統計表

年ごとに 1 表 (市区町村別・産業中分類別)。統計表番号は年によって 2-2 / 6-2 /
3-02 / 3-07 と変わり、集計の名前も「市区町村編」から「地域別」へ変わるため、
economic_census のように表番号では引けない。表題に「市区町村別」と
「産業中分類」を両方含む確報の表を年ごとに 1 件だけ選ぶ。

都道府県別の表 (「都道府県、東京特別区・政令指定都市別の産業中分類別統計」) は
取らない。市区町村別の表に都道府県の行が入っているため、同じ値を二重に持つ。

■ 2007 年 (平成19年確報) を取り込まない

産業中分類のコード 11〜31 が 2007 年と 2008 年以降で別の産業を指す。日本標準
産業分類の改定 (第12回、2008年適用) で繊維工業と衣服製造業が統合され、以降の
コードが 1 つずつ繰り上がったため、たとえば 26 は 2007 年が一般機械器具製造業、
2008 年以降は生産用機械器具製造業になる。同じコードで時系列を引くと黙って
別の産業が混ざるので、改定後の 2008 年から取り込む。

■ 年の欠け

2011 年と 2015・2016 年は工業統計調査が行われていない (経済センサス‐活動調査の
実施年にあたる)。2020 年確報が最後で、以降は経済構造実態調査に引き継がれた。

■ 軸の名前が年で変わる

2008〜2012 年は地域が area 軸、2013 年以降は cat03 軸に入る。同じ dlt テーブルに
積むため、cat03 は area に読み替える。集計項目 (cat01) のコード体系も
2014 年までの 9 桁 (010000000 など) と 2017 年以降の 8 桁 (32000070 など) で
違うが、コードはそのまま持ち、mart で共通の列名に開く。

統計表には時間軸が無く、年は統計表そのものが表す。dlt のマージキーに年が要る
ので、取得した年を survey_year 列として足す。
"""

import logging
from typing import Any, Dict, Iterator, List

import dlt
import pyarrow as pa
from estat_api_dlt_helper import EstatApiClient, estat_source, parse_response

from pipelines import EstatStatus

logger = logging.getLogger(__name__)

# 工業統計調査 (政府統計コード)
MANUFACTURE_STATS_CODE = "00550010"

# 日本標準産業分類 第12回改定の適用後。これより前は中分類コードの指す産業が違う。
FIRST_SURVEY_YEAR = 2008

MANUFACTURE_TABLE = "manufacture_municipality"

# 年 × 集計項目 × 産業中分類 × 地域 で 1 行。
MANUFACTURE_PRIMARY_KEY = ["survey_year", "cat01", "cat02", "area"]

# estat_table が既定で付ける取得パラメータと同じもの。自前のリソースで
# get_stats_data_generator を直接呼ぶため、ここに書く。
# replaceSpChars=2 は「-」(該当数字なし)・「X」(秘匿) などを空文字に置き換える。
API_PARAMS: Dict[str, str] = {
    "lang": "J",
    "metaGetFlg": "Y",
    "cntGetFlg": "N",
    "explanationGetFlg": "Y",
    "annotationGetFlg": "Y",
    "replaceSpChars": "2",
}


def fetch_manufacture_ids(app_id: str) -> Dict[int, str]:
    """年 -> statsDataId の対応を統計表の表題から引く。

    Args:
        app_id: e-Stat API アプリケーション ID。

    Returns:
        調査年 -> statsDataId。FIRST_SURVEY_YEAR 以降の年だけを含む。

    Raises:
        RuntimeError: API がエラーを返したとき、ある年で統計表が 1 件に
            定まらなかったとき、および 1 年も見つからなかったとき。0 件を
            握り潰すと、e-Stat 側の表題が変わっても dbt は前回ロード済みの
            _source でビルドに成功し、CI が緑のままテーブルが更新されなくなる。
    """
    client = EstatApiClient(app_id=app_id, timeout=300)
    try:
        result = client.get_stats_list(statsCode=MANUFACTURE_STATS_CODE, limit=100000)
    finally:
        client.close()

    stats_list = result.get("GET_STATS_LIST", {})
    status = stats_list.get("RESULT", {}).get("STATUS")
    if status not in (EstatStatus.OK, EstatStatus.PARTIAL):
        error_msg = stats_list.get("RESULT", {}).get("ERROR_MSG", "Unknown error")
        raise RuntimeError(f"manufacture: API error (status {status}): {error_msg}")

    tables = stats_list.get("DATALIST_INF", {}).get("TABLE_INF", [])
    if isinstance(tables, dict):
        tables = [tables]

    # 同じ @id が複数回現れるため年ごとに集合で持つ。
    by_year: Dict[int, set] = {}
    for t in tables:
        if "確報" not in str(t.get("STATISTICS_NAME") or ""):
            continue
        title = t.get("TITLE")
        title = title.get("$") if isinstance(title, dict) else str(title)
        if "市区町村別" not in title or "産業中分類" not in title:
            continue
        year = int(str(t.get("SURVEY_DATE"))[:4])
        if year < FIRST_SURVEY_YEAR:
            continue
        by_year.setdefault(year, set()).add(t["@id"])

    resolved: Dict[int, str] = {}
    for year, ids in sorted(by_year.items()):
        if len(ids) != 1:
            raise RuntimeError(
                f"manufacture: survey year {year} matched {len(ids)} ids "
                f"({sorted(ids)}) in statsCode={MANUFACTURE_STATS_CODE} "
                f"({len(tables)} rows scanned). "
                "e-Stat 側の表題が変わった可能性がある。"
            )
        resolved[year] = ids.pop()

    if not resolved:
        raise RuntimeError(
            f"manufacture: no survey year matched in "
            f"statsCode={MANUFACTURE_STATS_CODE} ({len(tables)} rows scanned). "
            "e-Stat 側の表題が変わった可能性がある。"
        )

    logger.info(f"manufacture: resolved {resolved}")
    return resolved


def normalize(table: pa.Table, survey_year: int) -> pa.Table:
    """年ごとに違う軸の名前をそろえ、調査年の列を足す。

    - 2013 年以降の地域軸 cat03 を area に読み替える (2012 年までは area)。
    - 統計表単位のメタ情報 stat_inf を落とす。全行に複製される約 670 バイトの
      冗長な列で、stg / mart からは参照しない。
    - 統計表に時間軸が無いため survey_year を足す。マージキーに要る。
    """
    if "cat03" in table.column_names:
        if "area" in table.column_names:
            raise RuntimeError(
                f"manufacture: {survey_year} has both area and cat03 axes; "
                "軸の読み替えが二重になる"
            )
        names = [
            {"cat03": "area", "cat03_metadata": "area_metadata"}.get(n, n)
            for n in table.column_names
        ]
        table = table.rename_columns(names)

    if "stat_inf" in table.column_names:
        table = table.drop_columns(["stat_inf"])

    return table.append_column(
        "survey_year", pa.array([survey_year] * len(table), type=pa.int32())
    )


def fetch_manufacture_tables(
    app_id: str, ids: Dict[int, str]
) -> Iterator[pa.Table]:
    """年ごとに統計表を取得し、軸をそろえた Arrow テーブルを順に返す。"""
    client = EstatApiClient(app_id=app_id, timeout=300)
    try:
        for year, stats_data_id in sorted(ids.items()):
            logger.info(f"manufacture: fetching {year} ({stats_data_id})")
            for response in client.get_stats_data_generator(
                stats_data_id=stats_data_id, limit_per_request=100000, **API_PARAMS
            ):
                table = parse_response(response)
                if table is None or len(table) == 0:
                    continue
                yield normalize(table, year)
    finally:
        client.close()


def create_manufacture_source(app_id: str, ids: Dict[int, str]):
    """市区町村別・産業中分類別統計のソースを作成する。

    年ごとに統計表が分かれているが、1 つの dlt テーブルに積む。統計表を
    そのままテーブルにすると年の数だけテーブルが増え、年が足されるたびに
    モデルの追加が要る。
    """

    @dlt.resource(
        name=MANUFACTURE_TABLE,
        write_disposition="merge",
        primary_key=MANUFACTURE_PRIMARY_KEY,
        schema_contract={
            "tables": "evolve",
            "columns": "evolve",
            "data_type": "freeze",
        },
    )
    def manufacture_municipality() -> Iterator[pa.Table]:
        yield from fetch_manufacture_tables(app_id, ids)

    resources: List[Any] = [manufacture_municipality()]
    return estat_source(tables=resources, app_id=app_id)
