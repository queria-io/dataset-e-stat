SELECT
    year,
    area,
    area_name,
    prefecture_code,
    industry_code,
    industry,
    sex_code,
    sex,
    scheduled_earnings,
    annual_special_earnings
FROM {{ ref('stg_wage_structure_prefecture_industry') }}
