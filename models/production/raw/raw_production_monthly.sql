{# 経済産業省生産動態統計 月報の統計表（確報）の実数表。main.py の build_production が毎回
   e-Stat の統計表ファイルから取り直して data/production/monthly.parquet に書く。 #}
{{ config(materialized='table') }}
SELECT time, year, month, form_code, form_name, category, product_code, product_name, item_symbol, item_name, unit, value
FROM read_parquet('data/production/monthly.parquet')
ORDER BY form_code, product_code, item_symbol, time
