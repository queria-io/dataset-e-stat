SELECT
    time,
    year,
    month,
    business_order,
    business,
    business_en,
    business_level,
    sector,
    sales_billion_yen,
    yoy_index,
    source_sha256
FROM {{ ref('stg_commerce_sales_by_business') }}
