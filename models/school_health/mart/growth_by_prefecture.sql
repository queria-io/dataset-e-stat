SELECT
    year,
    age,
    sex_code,
    sex,
    area,
    area_name,
    prefecture_code,
    height_mean,
    height_sd,
    weight_mean,
    weight_sd,
    sitting_height_mean,
    sitting_height_sd
FROM {{ ref('stg_school_health_growth_by_prefecture') }}
