{# 普通貿易統計 品別国別表（全国分）の新しい年（through_year より後）。
   main.py の build_trade_recent が毎回 e-Stat から取り直して data/trade/recent.parquet に書く。
   品目で絞る問い合わせが行グループの統計で読む範囲を絞れるよう、HS コード順に並べてテーブルにする。 #}
{{ config(materialized='table') }}
SELECT flow, year, month, hs_code, country_code, unit1, unit2, quantity1, quantity2, value, release
FROM read_parquet('data/trade/recent.parquet')
ORDER BY hs_code, country_code, flow, year, month
