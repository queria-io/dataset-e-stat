SELECT
    tab, cat01, cat02, cat03, cat04, time, unit, value,
    cat01_metadata, cat04_metadata, time_metadata
FROM {{ source('estat_source', 'port_cargo_tonnage_annual') }}
