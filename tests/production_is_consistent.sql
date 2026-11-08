-- production.monthly が、原典の構造どおりに読めていることを検証する。結果が0行ならテスト成功。
--
-- 1. 2022年1月から最新の月まで月の抜けが無い
-- 2. キー（調査票・品目・アイテム・月）が一意
-- 3. 毎月、調査票が100以上・行が9,000以上ある（シートの読み落としに気付く。実測は毎月110前後・9,600前後）
-- 4. 負の値は品種振替と投入（石油製品の品種間の振り替え）にだけある

WITH m AS (
    SELECT * FROM {{ ref('monthly') }}
),

months AS (
    SELECT count(DISTINCT time) AS n, min(time) AS first_time,
        (max(year) * 12 + max_by(month, time)) - (min(year) * 12 + min_by(month, time)) + 1 AS expected
    FROM m
),

by_month AS (
    SELECT time, count(DISTINCT form_code) AS forms, count(*) AS n_rows
    FROM m
    GROUP BY time
)

SELECT 'months' AS check_name, n || ' from ' || first_time AS actual, expected || ' from 2022000101' AS expected
FROM months WHERE n <> expected OR first_time <> '2022000101'

UNION ALL
SELECT 'duplicate keys', count(*)::VARCHAR, '0'
FROM (SELECT 1 FROM m GROUP BY form_code, product_code, item_symbol, time HAVING count(*) > 1)
HAVING count(*) > 0

UNION ALL
SELECT 'size ' || time, forms || ' forms / ' || n_rows || ' rows', '>=100 / >=9000'
FROM by_month WHERE forms < 100 OR n_rows < 9000

UNION ALL
SELECT 'negative ' || item_name, count(*)::VARCHAR, '0'
FROM m WHERE value < 0 AND item_name NOT IN ('品種振替', '投入')
GROUP BY item_name
