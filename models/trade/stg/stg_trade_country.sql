SELECT country_code, country_name
FROM {{ ref('raw_trade_country') }}
