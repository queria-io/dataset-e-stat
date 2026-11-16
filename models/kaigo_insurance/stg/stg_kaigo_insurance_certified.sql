{# 保険者別 要介護 (要支援) 認定者数。raw の列をそのまま使う #}
{{ config(materialized='ephemeral') }}

SELECT fiscal_year, prefecture_name, insurer_name, insured_category, age_group, care_level, value
FROM {{ ref('raw_kaigo_insurance_certified') }}
