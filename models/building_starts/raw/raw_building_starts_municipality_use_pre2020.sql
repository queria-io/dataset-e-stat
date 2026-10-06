SELECT
    tab, cat01, area, time, unit, value,
    tab_metadata, cat01_metadata, area_metadata, time_metadata
FROM {{ source('estat_source', 'building_starts_municipality_use_pre2020') }}
