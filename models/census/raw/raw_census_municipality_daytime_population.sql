SELECT
    cat01, cat02, cat03, area, unit, value,
    cat01_metadata, cat03_metadata, area_metadata
FROM {{ source('estat_source', 'census_municipality_daytime_population') }}
