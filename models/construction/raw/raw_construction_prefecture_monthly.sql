SELECT
    tab, area, time, unit, value,
    tab_metadata, area_metadata, time_metadata
FROM {{ source('estat_source', 'construction_prefecture_monthly') }}
