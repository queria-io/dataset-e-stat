SELECT
    flow,
    CASE flow WHEN 'export' THEN '輸出' WHEN 'import' THEN '輸入' END AS flow_name,
    year,
    month,
    hs_code,
    substr(hs_code, 1, 2) AS hs2,
    substr(hs_code, 1, 4) AS hs4,
    substr(hs_code, 1, 6) AS hs6,
    country_code,
    unit1,
    unit2,
    quantity1,
    quantity2,
    value AS value_thousand_yen,
    release
FROM {{ ref('raw_trade_recent') }}
