SELECT
    area,
    area_name,
    area_level,
    parent_area,
    destination_area,
    destination_area_name,
    destination_area_level,
    cat01 AS sex_code,
    sex,
    unit,
    value
FROM {{ ref('stg_census_commuting_flow') }}
