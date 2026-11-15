SELECT
    time,
    year,
    month,
    form_code,
    form_name,
    category,
    product_code,
    product_name,
    item_symbol,
    item_name,
    unit,
    value
FROM {{ ref('stg_production_monthly') }}
