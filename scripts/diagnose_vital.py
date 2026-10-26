# 一時: vital_statistics_is_consistent の失敗行を見る (マージ前に消す)
import os

import duckdb

c = duckdb.connect()
c.execute("INSTALL ducklake; INSTALL sqlite; LOAD ducklake; LOAD sqlite;")
c.execute(
    f"ATTACH 'ducklake:sqlite:{os.environ['QUERIA_CATALOG_PATH']}' AS e_stat "
    f"(DATA_PATH '{os.environ['QUERIA_DATA_URL']}', READ_ONLY)"
)
sql = open("target/compiled/e_stat/tests/vital_statistics_is_consistent.sql").read()
for row in c.execute(sql).fetchall():
    print("FAIL", row)
for t, col in [("births_by_mother_age", "births"), ("deaths_by_age", "deaths"), ("deaths_by_cause", "deaths")]:
    print(t, c.execute(
        f"SELECT area_kind, COUNT(DISTINCT area_code), COUNT(*) FROM e_stat.vital_statistics.{t} "
        "WHERE area_kind IN ('nationwide','foreign','unknown') GROUP BY 1 ORDER BY 1").fetchall())
