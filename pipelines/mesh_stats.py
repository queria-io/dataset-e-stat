"""地域メッシュ統計 (1kmメッシュ) の取得 (searchKind=2 + getStatsData)。

メッシュ統計は小地域統計と同じく getStatsList のデフォルト(searchKind=1)では
返らない。searchKind=2 を指定して 1次メッシュごとの statsDataId を実行時に集め、
各 ID を getStatsData で取得する。estat_table は 1 ID = 1 リソースのため、
apply_hints で出力先テーブル名を揃えて 1 テーブルへ merge する。

■ 政府統計コードについて

地域メッシュ統計には独立した政府統計コード 00200511 があるが、**API では 0 件**で
検索できない (searchKind 1/2 とも「該当データなし」)。メッシュ統計の統計表は
国勢調査 (00200521) と経済センサス‐活動調査 (00200553) の配下に登録されている。

■ 対象表の選び方

STATISTICS_NAME に調査年・集計単位・測地系が入る (例: "令和２年国勢調査
世界測地系(1KMメッシュ)")。TITLE_SPEC.TABLE_NAME が表の内容、
TITLE_SPEC.TABLE_SUB_CATEGORY2 が配布単位である 1次メッシュのコード。
統計表 ID をハードコードせず、この 2 つで引く。

■ API に無い表

令和2年国勢調査のメッシュ統計は API には「人口及び世帯」しか登録されていない。
労働力状態・従業地通学地 (平成27年には「その２ 人口移動集計及び就業状態等基本集計に
関する事項」「その３ 従業地・通学地集計及び世帯構造等基本集計に関する事項」として
ある) は統計GIS では公開済みだが API 未登録。経済センサスのメッシュも平成24年・
平成28年までで令和3年は未登録。API への登録は表単位で順次進んでいるため
(令和2年小地域も 2022-07-15 に6種類、2022-09-30 に3種類と段階的に追加された)、
これらも将来追加される見込み。追加されたらここに足す。
"""

import logging
from typing import List, Optional

from estat_api_dlt_helper import estat_source, estat_table

from pipelines import EstatStatus
from pipelines.ssds import drop_stat_inf

# TABLE_INF の COLLECT_AREA 欠落に対応する互換パッチ。import した時点で当たる。
from pipelines import estat_compat  # noqa: F401
from estat_api_dlt_helper.api.client import EstatApiClient

logger = logging.getLogger(__name__)

# 取り込むメッシュ統計表。
#
# primary_key は表ごとに違う。国勢調査メッシュは cat02 に秘匿・合算区分を持つが、
# 経済センサスメッシュは cat01 と area だけで cat02 が無い。
MESH_STATS_TABLES = [
    {
        "name": "mesh_population",
        "stats_code": "00200521",
        "statistics_name": "令和２年国勢調査 世界測地系(1KMメッシュ)",
        "table_name": "人口及び世帯",
        "primary_key": ["cat01", "cat02", "area"],
    },
    {
        "name": "mesh_establishment",
        "stats_code": "00200553",
        "statistics_name": "平成２８年経済センサス活動調査 世界測地系(1KMメッシュ)",
        "table_name": "産業（大分類）別事業所数及び従業者数",
        "primary_key": ["cat01", "area"],
    },
]


# 手元でだけ取り込むメッシュ統計表。
#
# 250mメッシュは全国で約5,800万行あり、毎日の CI でロードすると GitHub ランナーの
# メモリに収まらない。令和2年国勢調査の値は次の調査まで変わらないので、手元で一度だけ
# 取り込み (load_local_mesh.py)、CI では取り込まずに前回ロード分から dbt で作り直す。
# 毎回全件を入れ直すので merge ではなく replace で書く (merge の重複排除を避ける)。
LOCAL_MESH_STATS_TABLES = [
    {
        "name": "mesh_population_250m",
        "stats_code": "00200521",
        "statistics_name": "令和２年国勢調査 世界測地系(250Mメッシュ)",
        "table_name": "人口及び世帯",
        "primary_key": ["cat01", "cat02", "area"],
        "write_disposition": "replace",
    },
]


def _text(value) -> str:
    """API レスポンスの文字列フィールド ({"$": ...} 形式もある) を取り出す。"""
    if isinstance(value, dict):
        return str(value.get("$", ""))
    return "" if value is None else str(value)


def fetch_mesh_ids(
    app_id: str, stats_code: str, statistics_name: str, table_name: str
) -> List[str]:
    """指定した統計・集計単位・表名のメッシュ統計表 ID を集める。

    Args:
        app_id: e-Stat API アプリケーション ID。
        stats_code: 政府統計コード (国勢調査 00200521 / 経済センサス 00200553)。
        statistics_name: STATISTICS_NAME の完全一致値。調査年・集計単位・測地系が
            ここに入る。例: "令和２年国勢調査 世界測地系(1KMメッシュ)"
        table_name: TITLE_SPEC.TABLE_NAME の完全一致値。例: "人口及び世帯"

    Returns:
        条件に合致する statsDataId のリスト(配布単位である 1次メッシュの数だけ返る)。

    Raises:
        RuntimeError: API がエラーを返したとき、および条件に合致する表が 1 件も
            無かったとき。0 件を返して呼び出し側に握らせると、e-Stat が表題を
            変えたときにロードが黙って飛ばされ、dbt は前回ロード済みの
            _source をそのまま使ってビルドに成功してしまう。CI が緑のまま
            テーブルが更新されなくなるので、ここで落とす。
    """
    client = EstatApiClient(app_id=app_id, timeout=300)
    # searchKind=2 の 00200521 は約5,300表returned。既定の limit に頼らず明示する。
    result = client.get_stats_list(
        statsCode=stats_code, searchKind=2, limit=100000
    )

    stats_list = result.get("GET_STATS_LIST", {})
    status = stats_list.get("RESULT", {}).get("STATUS")
    if status not in (EstatStatus.OK, EstatStatus.PARTIAL):
        error_msg = stats_list.get("RESULT", {}).get("ERROR_MSG", "Unknown error")
        raise RuntimeError(f"mesh_stats: API error (status {status}): {error_msg}")

    tables = stats_list.get("DATALIST_INF", {}).get("TABLE_INF", [])
    if isinstance(tables, dict):
        tables = [tables]

    ids: List[str] = []
    for t in tables:
        if _text(t.get("STATISTICS_NAME")) != statistics_name:
            continue
        spec = t.get("TITLE_SPEC") or {}
        if _text(spec.get("TABLE_NAME")) != table_name:
            continue
        ids.append(t["@id"])

    if not ids:
        raise RuntimeError(
            f"mesh_stats: no tables matched STATISTICS_NAME='{statistics_name}' / "
            f"TABLE_NAME='{table_name}' in statsCode={stats_code} "
            f"({len(tables)} tables scanned). "
            "e-Stat 側の表題が変わった可能性がある。MESH_STATS_TABLES を確認する。"
        )

    logger.info(f"mesh_stats: {len(ids)} tables for '{statistics_name}' / '{table_name}'")
    return ids


def create_mesh_source(
    app_id: str,
    stats_data_ids: List[str],
    table_name: str,
    primary_key: List[str],
    maximum_offset: Optional[int] = None,
    write_disposition: str = "merge",
):
    """複数の1次メッシュの統計表を 1 テーブルへ集約するソースを作成する。

    stat_inf は小地域統計と同様に除去する。含んだままだと行ごとに複製される
    メタデータ struct のせいで merge SQL が GitHub ランナーの DuckDB
    memory_limit を超えて OOM になる。
    """
    resources = []
    for sid in stats_data_ids:
        resource = estat_table(
            stats_data_id=sid,
            app_id=app_id,
            table_name=f"_mesh_{sid}",
            write_disposition=write_disposition,
            primary_key=primary_key,
            maximum_offset=maximum_offset,
        )
        resource.add_map(drop_stat_inf)
        resource.apply_hints(table_name=table_name)
        resources.append(resource)
    return estat_source(tables=resources, app_id=app_id)
