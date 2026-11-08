-- 普通貿易統計 品別国別表の新しい年（raw_trade_recent、毎日取り直す分）が、原典の構造どおりに
-- 読めていることを検証する。結果が0行ならテスト成功。
--
-- 1. 年ごとに 輸出・輸入の両方があり、1月から公表済みの月まで抜けが無い
-- 2. キー（輸出入・年・月・HS・国）が一意
-- 3. HS コード（9文字）と国名コード（3桁）の形
-- 4. どの国名コードにも国名がある（国名は手元で取り込む raw_trade_country。新しい国名コードが
--    出たら気付くため。国名がまだ公開されていないカタログでは見ない）

WITH r AS (
    SELECT * FROM {{ ref('raw_trade_recent') }}
),

by_year AS (
    SELECT year, count(DISTINCT flow) AS flows
    FROM r
    GROUP BY year
),

by_flow AS (
    SELECT flow, year, count(DISTINCT month) AS months, max(month) AS last_month
    FROM r
    GROUP BY flow, year
)

SELECT 'empty' AS check_name, count(*)::VARCHAR AS actual, '>0' AS expected
FROM r
HAVING count(*) = 0

UNION ALL

SELECT 'flows ' || year, flows::VARCHAR, '2'
FROM by_year
WHERE flows <> 2

UNION ALL

SELECT 'months ' || flow || ' ' || year, months || ' / ' || last_month, 'months = last_month'
FROM by_flow
WHERE months <> last_month

UNION ALL

SELECT 'duplicate keys', count(*)::VARCHAR, '0'
FROM (
    SELECT 1 FROM r
    GROUP BY flow, year, month, hs_code, country_code
    HAVING count(*) > 1
)
HAVING count(*) > 0

UNION ALL

SELECT 'bad keys', count(*)::VARCHAR, '0'
FROM r
WHERE NOT regexp_full_match(hs_code, '[0-9A-Z]{9}') OR NOT regexp_full_match(country_code, '[0-9]{3}')
HAVING count(*) > 0
{% if local_source_loaded('trade_country') %}

UNION ALL

SELECT 'country without name ' || country_code, count(*)::VARCHAR, '0'
FROM r
WHERE country_code NOT IN (SELECT country_code FROM {{ ref('raw_trade_country') }})
GROUP BY country_code
{% endif %}
