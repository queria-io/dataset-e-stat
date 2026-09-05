SELECT
    cat01, cat02, area, unit, value,
    cat01_metadata, cat02_metadata, area_metadata
FROM {{ source('estat_source', 'census_commuting_flow') }}
