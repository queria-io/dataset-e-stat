SELECT
    area,
    area_name,
    area_level,
    parent_area,
    cat01 AS sex_code,
    sex,
    cat03 AS location_code,
    location,
    location_level,
    population_base,
    is_reprint,
    unit,
    value
FROM {{ ref('stg_census_municipality_daytime_population') }}
