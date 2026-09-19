SELECT
    tab, cat01, cat02, area, time, unit, value,
    cat02_metadata, area_metadata, time_metadata
FROM {{ source('estat_source', 'retail_price_annual') }}
