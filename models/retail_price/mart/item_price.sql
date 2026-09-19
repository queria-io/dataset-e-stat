SELECT
    cat02,
    item_name,
    item_note,
    area,
    area_name,
    area_note,
    time,
    time_name,
    year,
    unit,
    value
FROM {{ ref('stg_retail_price_annual') }}
