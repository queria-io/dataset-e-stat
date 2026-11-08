SELECT
    fiscal_year,
    survey_year,
    industry_code,
    industry_name,
    breakdown_code AS subsidiary_industry_code,
    breakdown_name AS subsidiary_industry_name,
    measure_code,
    measure,
    unit,
    value
FROM (
    SELECT * FROM {{ ref('stg_enterprise_activity') }}
    UNION ALL
    SELECT * FROM {{ ref('stg_enterprise_activity_legacy') }}
)
WHERE kind = 'subsidiary' AND fiscal_year = survey_year - 1
