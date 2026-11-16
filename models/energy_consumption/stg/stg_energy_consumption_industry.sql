{# 都道府県別・業種別エネルギー消費量 (TJ)。raw の列をそのまま使う #}
{{ config(materialized='ephemeral') }}

SELECT fiscal_year, prefecture_name, industry_code, industry_name, parent_industry_code, value
FROM {{ ref('raw_energy_consumption_industry') }}
