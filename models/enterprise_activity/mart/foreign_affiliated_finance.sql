SELECT
    fiscal_year,
    survey_year,
    industry_code,
    industry_name,
    measure_code,
    measure,
    unit,
    value
FROM {{ ref('stg_enterprise_activity') }}
WHERE kind = 'foreign' AND fiscal_year = survey_year - 1
