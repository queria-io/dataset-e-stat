SELECT
    fiscal_year,
    survey_year,
    industry_code,
    industry_name,
    CASE WHEN breakdown_code = '00' THEN '00000' ELSE breakdown_code || '000' END AS area,
    CASE WHEN breakdown_code = '00' THEN '全国' ELSE breakdown_name END AS prefecture_name,
    measure_code,
    measure,
    unit,
    value
FROM (
    SELECT * FROM {{ ref('stg_enterprise_activity') }}
    UNION ALL
    SELECT * FROM {{ ref('stg_enterprise_activity_legacy') }}
)
WHERE kind = 'prefecture' AND fiscal_year = survey_year - 1
