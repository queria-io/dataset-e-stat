"""社会・人口統計体系データ取得 (getStatsData)。"""

import dlt
import pyarrow as pa
from estat_api_dlt_helper import estat_source, estat_table


def drop_stat_inf(table: pa.Table) -> pa.Table:
    """行ごとに複製される stat_inf (統計表メタ) 列を落とす。

    estat_api_dlt_helper は全行に同一の TABLE_INF struct (統計表名・調査日等、
    約670バイト/行で 1 行の約8割) を複製して載せる。この情報は別リソース由来の
    main.stats_catalog / main.stg_stats_list に統計表単位で完全に含まれており、
    stg / mart からは一切参照されない冗長な列。ロード時の DuckDB メモリを支配し
    巨大テーブルでは OOM の原因になるため、SSDS と census 系の全テーブルで除去する。
    """
    if "stat_inf" in table.column_names:
        return table.drop_columns(["stat_inf"])
    return table


def _build_table(app_id: str, t: dict):
    # api_params は取得そのものを絞る (cdCat01 等)。分類軸の一部しか要らない表で
    # 全量を取ると、使わない区分のために取得も保存も何倍にもなる。取得後に
    # dbt で捨てるのでは API の往復が減らない。
    resource = estat_table(
        stats_data_id=t["statsDataId"],
        table_name=t["name"],
        write_disposition="merge" if t.get("merge_keys") else "replace",
        primary_key=t.get("merge_keys"),
        app_id=app_id,
        incremental=dlt.sources.incremental("time", initial_value="0000000000")
        if t.get("incremental")
        else None,
        **t.get("api_params", {}),
    )
    # stat_inf は全テーブルで冗長なため、テーブルを問わず常に除去する。
    return resource.add_map(drop_stat_inf)


def create_source(app_id: str, tables_config: dict):
    """tables.yml の設定から SSDS データソースを作成する。"""
    return estat_source(
        app_id=app_id,
        tables=[_build_table(app_id, t) for t in tables_config["tables"]],
    )
