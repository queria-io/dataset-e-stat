{# 保険者別 第1号被保険者数。raw の列をそのまま使う #}
{{ config(materialized='ephemeral') }}

SELECT fiscal_year, prefecture_name, insurer_name, category, value
FROM {{ ref('raw_kaigo_insurance_insured') }}
