{# 都道府県別・エネルギー種別エネルギー消費量 (TJ)。raw の列をそのまま使う #}
{{ config(materialized='ephemeral') }}

SELECT fiscal_year, prefecture_name, energy_type, parent_energy_type, value
FROM {{ ref('raw_energy_consumption_energy_type') }}
