{# 過去の年（手元で取り込んだ分）と新しい年（毎日取り直す分）を積む。約5,000万行あるので、
   テーブルにせずビューで積む。元の2つの表はどちらも HS コード順に並んでいる。
   新しい年の分は、過去の年の分の最後の年より後だけを使う。境目（through_year）を進める
   手順の途中では、手元で取り込み直した過去の年の分が、CI がまだ取り直している年を含む。
   その年を二重に数えないため。 #}
WITH unioned AS (
    SELECT * FROM {{ ref('raw_trade_history') }}
    UNION ALL
    SELECT * FROM {{ ref('raw_trade_recent') }}
    WHERE year > (SELECT coalesce(max(year), 0) FROM {{ ref('raw_trade_history') }})
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
