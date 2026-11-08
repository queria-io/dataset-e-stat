{# 普通貿易統計 品別国別表（全国分）の新しい年（through_year より後）。
   main.py の build_trade_recent が毎回 e-Stat から取り直して data/trade/recent.parquet に書く。
   HS コード順に並べて書いてあり、テーブルにしても並びは変わらない。 #}
{{ config(materialized='table') }}
SELECT flow, year, month, hs_code, country_code, unit1, unit2, quantity1, quantity2, value, release
FROM read_parquet('data/trade/recent.parquet')
