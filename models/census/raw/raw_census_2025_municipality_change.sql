SELECT
    tab, area, unit, value,
    tab_metadata, area_metadata
FROM {{ source('estat_source', 'census_2025_municipality_change') }}
