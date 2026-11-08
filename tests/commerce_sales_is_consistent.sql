-- commerce.sales_by_business_monthly が、原典の構造どおりに読めていることを検証する。結果が0行ならテスト成功。
--
-- 1. 1980年1月から最新の月まで月の抜けが無く、毎月31業種がそろう。業種の並びが原典どおり
--    （列の位置で段を決めているので、原典が列を足したら気付く）
-- 2. 商業計 = 卸売業計 + 小売業計、卸売業計 = 卸売の各業種の和、機械器具卸売業 = その内訳の和
--    （原典は業種ごとに10億円単位で丸めるので、足した数 × 0.5 程度のずれを許す。実測の最大は3）。
--    機械器具卸売業の内訳は古い月に空欄があるので、内訳が4つともある月だけ見る
-- 3. 小売業計 = 小売の各業種の和（2010年7月から）。それより前は医薬品・化粧品小売業などが空欄で、
--    小売業計 = 各種商品 + 織物・衣服・身の回り品 + 飲食料品 + 参考１ になる

WITH s AS (
    SELECT * FROM {{ ref('sales_by_business_monthly') }}
),

months AS (
    SELECT count(DISTINCT time) AS n, min(time) AS first_time,
        (max(year) * 12 + max_by(month, time)) - (min(year) * 12 + min_by(month, time)) + 1 AS expected
    FROM s
),

by_month AS (
    SELECT time,
        count(*) AS businesses,
        max(sales_billion_yen) FILTER (WHERE business_order = 0) AS total,
        max(sales_billion_yen) FILTER (WHERE business_order = 1) AS wholesale,
        max(sales_billion_yen) FILTER (WHERE business_order = 18) AS retail,
        sum(sales_billion_yen) FILTER (WHERE business_order BETWEEN 2 AND 10 OR business_order BETWEEN 15 AND 17) AS wholesale_parts,
        max(sales_billion_yen) FILTER (WHERE business_order = 10) AS machinery,
        sum(sales_billion_yen) FILTER (WHERE business_order BETWEEN 11 AND 14) AS machinery_parts,
        count(sales_billion_yen) FILTER (WHERE business_order BETWEEN 11 AND 14) AS machinery_known,
        count(sales_billion_yen) FILTER (WHERE business_order BETWEEN 19 AND 26) AS retail_known,
        sum(sales_billion_yen) FILTER (WHERE business_order BETWEEN 19 AND 27) AS retail_parts,
        sum(sales_billion_yen) FILTER (WHERE business_order BETWEEN 19 AND 21)
            + max(sales_billion_yen) FILTER (WHERE business_order = 29) AS retail_with_reference
    FROM s
    GROUP BY time
)

SELECT 'months' AS check_name, n || ' from ' || first_time AS actual, expected || ' from 1980000101' AS expected
FROM months WHERE n <> expected OR first_time <> '1980000101'

UNION ALL
SELECT 'businesses ' || time, businesses::VARCHAR, '31'
FROM by_month WHERE businesses <> 31

UNION ALL
SELECT 'business order', string_agg(business_order || ':' || business, ', ' ORDER BY business_order), '0:商業計, 1:卸売業計, 10:機械器具卸売業, 18:小売業計, 29:参考１…'
FROM (SELECT DISTINCT business_order, business FROM s)
WHERE (business_order, business) IN ((0, '商業計'), (1, '卸売業計'), (10, '機械器具卸売業'), (18, '小売業計'))
    OR (business_order = 29 AND business LIKE '参考１%')
HAVING count(*) <> 5

UNION ALL
SELECT 'total ' || time, (wholesale + retail)::VARCHAR, total::VARCHAR
FROM by_month WHERE NOT coalesce(abs(total - (wholesale + retail)) <= 1, false)

UNION ALL
SELECT 'wholesale ' || time, wholesale_parts::VARCHAR, wholesale::VARCHAR
FROM by_month WHERE NOT coalesce(abs(wholesale - wholesale_parts) <= 9, false)

UNION ALL
SELECT 'machinery ' || time, machinery_parts::VARCHAR, machinery::VARCHAR
FROM by_month WHERE machinery_known = 4 AND NOT coalesce(abs(machinery - machinery_parts) <= 4, false)

UNION ALL
SELECT 'retail ' || time,
    (CASE WHEN retail_known = 8 THEN retail_parts ELSE retail_with_reference END)::VARCHAR, retail::VARCHAR
FROM by_month
WHERE NOT coalesce(abs(retail - CASE WHEN retail_known = 8 THEN retail_parts ELSE retail_with_reference END) <= 9, false)
