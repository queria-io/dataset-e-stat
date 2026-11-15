SELECT time, year, month, form_code, form_name, category, product_code, product_name, item_symbol, item_name, unit, value,
    source_sha256, source_sheet, source_row
FROM {{ ref('raw_production_monthly') }}
