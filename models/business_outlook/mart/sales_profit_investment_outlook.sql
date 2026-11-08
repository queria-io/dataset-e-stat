SELECT
    survey_time,
    survey_name,
    survey_year,
    survey_quarter,
    outlook_table,
    fiscal_year,
    half,
    industry_code,
    industry_name,
    industry_level,
    item,
    measure,
    unit,
    value
FROM {{ ref('stg_business_outlook_outlook') }}
