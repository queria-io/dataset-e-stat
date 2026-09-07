SELECT
    survey_year, cat01, cat02, area, value,
    cat02_metadata, area_metadata
FROM {{ source('estat_source', 'manufacture_municipality') }}
