SELECT
    survey_time,
    survey_name,
    survey_year,
    survey_quarter,
    indicator,
    horizon_code,
    horizon,
    size_code,
    size,
    industry_code,
    industry_name,
    industry_level,
    value
FROM {{ ref('stg_business_outlook_bsi') }}
