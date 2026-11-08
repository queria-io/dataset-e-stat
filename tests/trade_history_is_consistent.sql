-- 普通貿易統計 品別国別表の過去の年（raw_trade_history）が、原典の構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 1. 1988年から最後の年まで、毎年 輸出・輸入とも 1〜12月がそろう
-- 2. HS コード（9文字）と国名コード（3桁）が空でなく、どの国名コードにも国名がある
--    （国名は raw_trade_country。データベースの地域軸から取るので、CSV にだけあるコードが出たら気付く）
-- 年計と月の和の一致は取得のとき（pipelines/trade.py の parse_csv）に確かめている。
-- 4,000万行あるので、ここではキーの一意を見ない（取得のときに確かめた）。
--
-- 元表は手元でだけ取り込む (load_local.py trade)。元表が無いカタログ
-- (CI でまだ公開していないとき) では 0 行の表になるので検査しない。

{% if local_source_loaded('trade_history') %}
WITH h AS (
    SELECT * FROM {{ ref('raw_trade_history') }}
),

months AS (
    SELECT flow, year, count(DISTINCT month) AS months
    FROM h
    GROUP BY flow, year
),

expected AS (
    SELECT flow, year
    FROM (VALUES ('export'), ('import')) AS f (flow),
        range(1988, (SELECT max(year) FROM h) + 1) AS r (year)
)

SELECT 'months ' || e.flow || ' ' || e.year AS check_name,
    coalesce(m.months, 0)::VARCHAR AS actual, '12' AS expected
FROM expected e
LEFT JOIN months m USING (flow, year)
WHERE coalesce(m.months, 0) <> 12

UNION ALL

SELECT 'bad keys', count(*)::VARCHAR, '0'
FROM h
WHERE NOT regexp_full_match(hs_code, '[0-9A-Z]{9}') OR NOT regexp_full_match(country_code, '[0-9]{3}')
HAVING count(*) > 0

UNION ALL

SELECT 'country without name ' || country_code, count(*)::VARCHAR, '0'
FROM h
WHERE country_code NOT IN (SELECT country_code FROM {{ ref('raw_trade_country') }})
GROUP BY country_code
{% else %}
SELECT NULL::VARCHAR AS check_name, NULL::VARCHAR AS actual, NULL::VARCHAR AS expected
WHERE FALSE
{% endif %}
