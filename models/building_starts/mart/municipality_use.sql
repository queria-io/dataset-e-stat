SELECT
    area,
    area_name,
    area_level,
    parent_area,
    year,
    use_code,
    use_name,
    buildings,
    floor_area,
    construction_cost
FROM {{ ref('stg_building_starts_municipality_use') }}
