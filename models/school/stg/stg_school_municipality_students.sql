{# 市町村別の表。raw の列をそのまま使う #}
{{ config(materialized='ephemeral') }}

SELECT survey_year, school_type, prefecture_name, municipality_code, municipality_name, grade, sex, value
FROM {{ ref('raw_school_municipality_students') }}
