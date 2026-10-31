-- rail_transport の mart が、原典の構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 業態は計（段1）・ＪＲ旅客会社と民鉄（段2）・新幹線と大手・中小・公営（段3）の3段で、
-- 計はＪＲ旅客会社と民鉄の和に、民鉄は大手・中小・公営の和に、どの月・どの定期区分でも
-- ちょうど一致する（実測）。段か親の読み方が崩れると、この恒等式が外れる。
--
-- 定期と定期外の和は千人の丸めで計とずれる（実測の最大は9千人）。業態ごとに丸めるので、
-- 20千人を超えたら値の読み方が崩れている。
--
-- 毎回全量を取り直して置き換える（replace）ので、原典から月が抜けると mart からも抜ける。
-- 2020年4月から最新月までの月がすべてあり、各月に7業態 × 3区分がそろうことを見る。

WITH mart AS (
    SELECT * FROM {{ ref('passengers_monthly') }}
),

v AS (
    SELECT operator_type_code AS op, ticket_type_code AS tt, time, passengers
    FROM mart
),

months AS (
    SELECT DISTINCT year * 100 + month AS ym FROM mart
),

expected_months AS (
    SELECT YEAR(d) * 100 + MONTH(d) AS ym
    FROM (
        SELECT UNNEST(RANGE(
            DATE '2020-04-01',
            (SELECT MAKE_DATE(MAX(year * 100 + month) // 100, MAX(year * 100 + month) % 100, 1) FROM mart)
                + INTERVAL 1 MONTH,
            INTERVAL 1 MONTH
        )) AS d
    )
),

by_op AS (
    SELECT tt, time,
        MAX(passengers) FILTER (WHERE op = '160') AS total,
        MAX(passengers) FILTER (WHERE op = '100') AS jr,
        MAX(passengers) FILTER (WHERE op = '120') AS private,
        MAX(passengers) FILTER (WHERE op = '130') AS major,
        MAX(passengers) FILTER (WHERE op = '140') AS small,
        MAX(passengers) FILTER (WHERE op = '150') AS public
    FROM v
    GROUP BY tt, time
),

by_ticket AS (
    SELECT op, time,
        MAX(passengers) FILTER (WHERE tt = '100') AS total,
        MAX(passengers) FILTER (WHERE tt = '110') AS commuter,
        MAX(passengers) FILTER (WHERE tt = '120') AS non_commuter
    FROM v
    GROUP BY op, time
)

SELECT '行が無い、または収録が2020年4月から始まっていない' AS violation,
    COALESCE(CAST(min_ym AS VARCHAR), 'empty') AS detail
FROM (SELECT COUNT(*) AS rows, MIN(year * 100 + month) AS min_ym FROM mart)
WHERE rows = 0 OR min_ym <> 202004

UNION ALL

SELECT '収録されていない月がある', CAST(e.ym AS VARCHAR)
FROM expected_months e
LEFT JOIN months m USING (ym)
WHERE m.ym IS NULL

UNION ALL

SELECT '月に7業態 × 3区分がそろわないか、重複がある', time || ' ' || CAST(COUNT(*) AS VARCHAR)
FROM mart
GROUP BY time
HAVING COUNT(*) <> 21 OR COUNT(DISTINCT operator_type_code || '-' || ticket_type_code) <> 21

UNION ALL

SELECT '業態の段か親が想定と違う', operator_type_code
FROM (SELECT DISTINCT operator_type_code, operator_type_level, operator_type_parent_code FROM mart)
WHERE NOT (
    (operator_type_code = '160' AND operator_type_level IS NOT DISTINCT FROM 1
        AND operator_type_parent_code IS NULL)
    OR (operator_type_code IN ('100', '120') AND operator_type_level IS NOT DISTINCT FROM 2
        AND operator_type_parent_code IS NULL)
    OR (operator_type_code = '110' AND operator_type_level IS NOT DISTINCT FROM 3
        AND operator_type_parent_code IS NOT DISTINCT FROM '100')
    OR (operator_type_code IN ('130', '140', '150') AND operator_type_level IS NOT DISTINCT FROM 3
        AND operator_type_parent_code IS NOT DISTINCT FROM '120')
)

UNION ALL

SELECT '旅客数量が 0 以下か NULL', operator_type_code || ' ' || ticket_type_code || ' ' || time
FROM mart
WHERE passengers IS NULL OR passengers <= 0

UNION ALL

SELECT '計がＪＲ旅客会社と民鉄の和に一致しない', tt || ' ' || time
FROM by_op
WHERE total IS DISTINCT FROM jr + private

UNION ALL

SELECT '民鉄が大手・中小・公営の和に一致しない', tt || ' ' || time
FROM by_op
WHERE private IS DISTINCT FROM major + small + public

UNION ALL

SELECT '定期と定期外の和が丸めの範囲を超えて計とずれる',
    op || ' ' || time || ' ' || CAST(total - commuter - non_commuter AS VARCHAR)
FROM by_ticket
WHERE total IS NULL OR ABS(total - commuter - non_commuter) > 20
