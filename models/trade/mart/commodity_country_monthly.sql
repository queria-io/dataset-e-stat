{# 過去の年（手元で取り込んだ分）と新しい年（毎日取り直す分）を積む。年は重ならない
   （過去の年は through_year まで、新しい年はその後）。約4,000万行あるので、テーブルに
   せずビューで積む。元の2つの表はどちらも HS コード順に並んでいる。 #}
WITH unioned AS (
    SELECT * FROM {{ ref('raw_trade_history') }}
    UNION ALL
    SELECT * FROM {{ ref('raw_trade_recent') }}
)

SELECT
    u.flow,
    CASE u.flow WHEN 'export' THEN '輸出' WHEN 'import' THEN '輸入' END AS flow_name,
    u.year,
    u.month,
    u.hs_code,
    substr(u.hs_code, 1, 2) AS hs2,
    substr(u.hs_code, 1, 4) AS hs4,
    substr(u.hs_code, 1, 6) AS hs6,
    u.country_code,
    c.country_name,
    u.unit1,
    u.unit2,
    u.quantity1,
    u.quantity2,
    u.value AS value_thousand_yen,
    u.release
FROM unioned u
LEFT JOIN {{ ref('raw_trade_country') }} c USING (country_code)
