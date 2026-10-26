SELECT
    cat01, area, unit, value,
    cat01_metadata, area_metadata
FROM {{ source('estat_source', 'census_2025_municipality_population') }}
