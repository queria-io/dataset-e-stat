SELECT
    mesh_code,
    city_code,
    CAST(nighttime_population AS BIGINT) AS nighttime_population,
    CAST(ROUND(daytime_population) AS BIGINT) AS daytime_population,
    CASE
        WHEN nighttime_population > 0
            THEN ROUND(daytime_population * 100.0 / nighttime_population, 1)
    END AS daytime_ratio,
    CAST(ROUND(daytime_population) AS BIGINT)
    - CAST(nighttime_population AS BIGINT) AS daytime_night_diff,
    CAST(employees AS BIGINT) AS employees,
    CAST(establishments AS BIGINT) AS establishments
FROM {{ ref('mesh_daytime_population') }}
