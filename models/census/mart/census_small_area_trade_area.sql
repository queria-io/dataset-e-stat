SELECT
    area,
    source,
    cat01,
    cat02,
    value
FROM {{ ref('stg_census_small_area_trade_area') }}
