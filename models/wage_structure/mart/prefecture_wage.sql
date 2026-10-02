SELECT
    year,
    area,
    area_name,
    prefecture_code,
    sex_code,
    sex,
    age,
    tenure_years,
    scheduled_hours,
    overtime_hours,
    contractual_earnings,
    scheduled_earnings,
    annual_special_earnings,
    workers
FROM {{ ref('stg_wage_structure_prefecture') }}
