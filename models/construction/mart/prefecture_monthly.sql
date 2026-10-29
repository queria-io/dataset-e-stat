SELECT
    prefecture_code,
    area,
    area_name,
    region_code,
    region_name,
    time,
    time_name,
    year,
    month,
    output
FROM {{ ref('stg_construction_prefecture_monthly') }}
