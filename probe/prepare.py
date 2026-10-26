import sys, os
sys.path.insert(0, os.getcwd())
import duckdb
from pipelines.municipality_code import build_municipality_code
build_municipality_code("data/municipality_code")
con = duckdb.connect("e_stat.duckdb")
con.sql("create schema if not exists _source")
for t in ("kaigo_insurance_insured", "kaigo_insurance_certified"):
    con.sql(f"create or replace table _source.{t} as select * from read_parquet('data/local/kaigo_insurance/{t}.2026-08-27.parquet')")
    print(t, con.sql(f"select count(*) from _source.{t}").fetchone())
