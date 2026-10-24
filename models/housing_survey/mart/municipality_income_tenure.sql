SELECT
    area,
    area_name,
    area_level,
    parent_area,
    tenure_code,
    tenure,
    income_class_code,
    income_class,
    income_lower,
    income_upper,
    households
FROM {{ ref('stg_housing_survey_income_tenure') }}
