{# 過去の年（手元で取り込んだ分）と新しい年（毎日取り直す分）を積む。約5,000万行ある。
   元の2つの表はどちらも HS コード順に並んでいる。
   新しい年の分は、過去の年の分の最後の年より後だけを使う。境目（through_year）を進める
   手順の途中では、手元で取り込み直した過去の年の分が、CI がまだ取り直している年を含む。
   その年を二重に数えないため。 #}
WITH unioned AS (
    SELECT * FROM {{ ref('stg_trade_history') }}
    UNION ALL
    SELECT * FROM {{ ref('stg_trade_recent') }}
    WHERE year > (SELECT coalesce(max(year), 0) FROM {{ ref('stg_trade_history') }})
)

SELECT
    u.flow,
    u.flow_name,
    u.year,
    u.month,
    u.hs_code,
    u.hs2,
    u.hs4,
    u.hs6,
    u.country_code,
    c.country_name,
    u.unit1,
    u.unit2,
    u.quantity1,
    u.quantity2,
    u.value_thousand_yen,
    u.release
FROM unioned u
LEFT JOIN {{ ref('stg_trade_country') }} c USING (country_code)
