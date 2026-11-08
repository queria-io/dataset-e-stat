{# 商業動態統計調査 業種別商業販売額と前年同月比（月次）。main.py の build_commerce_sales が
   毎回 e-Stat の統計表ファイルから取り直して data/commerce/sales_by_business.parquet に書く。 #}
{{ config(materialized='table') }}
SELECT time, year, month, business_order, business, business_en, sales_billion_yen, yoy_index
FROM read_parquet('data/commerce/sales_by_business.parquet')
ORDER BY business_order, time
