SELECT
    tab, cat01, cat02, time, unit, value,
    cat01_metadata, cat02_metadata, time_metadata
FROM {{ source('estat_source', 'rail_transport_passengers_monthly') }}
