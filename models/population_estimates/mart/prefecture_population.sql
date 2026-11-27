SELECT
    area,
    area_name,
    area_level,
    sex_code,
    sex,
    population_type_code,
    population_type,
    time,
    year,
    population
FROM {{ ref('stg_population_estimates_prefecture') }}
