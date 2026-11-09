"""取り込んだ統計表の e-Stat の更新日を記録し、変わっていない表の取得を省く。

小地域統計と 1km メッシュ統計は数年に 1 度しか変わらないのに、毎日の Sync で
600 表あまりを取り直すと 110 分かかる。getStatsList が返す表ごとの更新日
(UPDATED_DATE) を _source.loaded_stats_tables に残し、次の Sync では更新日が
前回と違う表と、まだ取り込んでいない表だけを取得する。

記録はデータのロードが成功したあとに書く。ロードが途中で落ちたときは記録が
残らないので、次の Sync で取り直す。

更新日は日付単位なので、e-Stat が同じ日に表を 2 回直すと、古いデータに新しい
更新日が付いたまま残ることがある。毎月 1 日 (UTC) の Sync は記録を見ずに全表を
取り直して、こうしたずれを直す。
"""

import logging
from datetime import date

import dlt
from dlt.destinations.exceptions import DatabaseUndefinedRelation

logger = logging.getLogger("pipelines")

TABLE_NAME = "loaded_stats_tables"


def updated_date(table_inf: dict) -> str | None:
    """getStatsList の TABLE_INF から更新日を取り出す。"""
    value = table_inf.get("UPDATED_DATE")
    if isinstance(value, dict):
        value = value.get("$")
    return str(value) if value else None


def refetch_all(today: date) -> bool:
    """記録を見ずに全表を取り直す日か。毎月 1 日に取り直す。"""
    return today.day == 1


def loaded_updated_dates(pipeline) -> dict[str, dict[str, str]]:
    """前回までに取り込んだ統計表の更新日を {テーブル名: {統計表 ID: 更新日}} で返す。

    同じ統計表を別のテーブルへ取り込んだときや、取り込み先のテーブル名を変えたときに
    取り込み済みと見なさないよう、取り込み先のテーブルごとに分ける。
    """
    try:
        with pipeline.sql_client() as client:
            table = client.make_qualified_table_name(TABLE_NAME)
            rows = client.execute_sql(
                f"SELECT table_name, stats_data_id, updated_date FROM {table}"
            )
    except DatabaseUndefinedRelation:
        return {}
    loaded: dict[str, dict[str, str]] = {}
    for table_name, sid, date in rows:
        loaded.setdefault(table_name, {})[sid] = date
    return loaded


def changed_ids(current: dict[str, str | None], loaded: dict[str, str]) -> list[str]:
    """更新日が前回と違う表と、まだ取り込んでいない表の ID を返す。

    更新日の無い表は判定できないので、毎回取得する。
    """
    return [
        sid
        for sid, date in current.items()
        if date is None or loaded.get(sid) != date
    ]


def record(pipeline, table_name: str, current: dict[str, str | None], ids: list[str]) -> None:
    """取り込んだ表の更新日を記録する。"""
    rows = [
        {"stats_data_id": sid, "updated_date": current[sid], "table_name": table_name}
        for sid in ids
        if current[sid] is not None
    ]
    if not rows:
        return
    pipeline.run(
        dlt.resource(
            rows,
            name=TABLE_NAME,
            write_disposition="merge",
            primary_key=["table_name", "stats_data_id"],
        )
    )


def load_changed(pipeline, table_name: str, current: dict[str, str | None], loaded: dict[str, dict[str, str]], make_source) -> None:
    """更新された表だけを make_source(ids) で取り込み、更新日を記録する。"""
    ids = changed_ids(current, loaded.get(table_name, {}))
    logger.info(f"  {table_name}: {len(current)} 表のうち {len(ids)} 表を取得")
    if not ids:
        return
    info = pipeline.run(make_source(ids))
    logger.info(f"  {table_name}: {info}")
    record(pipeline, table_name, current, ids)
