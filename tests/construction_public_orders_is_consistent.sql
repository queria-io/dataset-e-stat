-- construction.public_orders_prefecture_monthly が、原典の表の構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 原典は月ごとに1ファイルで、全国計と47都道府県の行に、発注機関の7区分と
-- 国の機関・地方の機関の小計、合計が並ぶ。都道府県を足すと全国計に、発注機関を
-- 足すと小計と合計に一致する（実測の差は浮動小数の端数だけ）。列の取り違えや
-- 行の読み落としがあると、このどちらかが崩れる。
--
-- 毎回全量を取り直すので、原典から月が抜けると mart からも抜ける。2021年4月から
-- 最新月までの月がすべてあることを見る。

WITH mart AS (
    SELECT * FROM {{ ref('public_orders_prefecture_monthly') }}
),

months AS (
    SELECT DISTINCT year * 100 + month AS ym FROM mart
),

expected_months AS (
    SELECT YEAR(d) * 100 + MONTH(d) AS ym
    FROM (
        SELECT UNNEST(RANGE(
            DATE '2021-04-01',
            (SELECT MAKE_DATE(MAX(year * 100 + month) // 100, MAX(year * 100 + month) % 100, 1) FROM mart)
                + INTERVAL 1 MONTH,
            INTERVAL 1 MONTH
        )) AS d
    )
),

prefecture_sums AS (
    SELECT year, month,
        SUM(total) AS total,
        SUM(national_total) AS national_total,
        SUM(local_total) AS local_total,
        SUM(national_government) AS national_government,
        SUM(municipal_government) AS municipal_government
    FROM mart
    WHERE area <> '00000'
    GROUP BY year, month
),

nationwide AS (
    SELECT * FROM mart WHERE area = '00000'
)

SELECT '行が無い、または収録が2021年4月から始まっていない' AS violation,
    COALESCE(CAST(min_ym AS VARCHAR), 'empty') AS detail
FROM (SELECT COUNT(*) AS rows, MIN(year * 100 + month) AS min_ym FROM mart)
WHERE rows = 0 OR min_ym <> 202104

UNION ALL

SELECT '収録されていない月がある', CAST(e.ym AS VARCHAR)
FROM expected_months e
LEFT JOIN months m USING (ym)
WHERE m.ym IS NULL

UNION ALL

SELECT '月に全国計と47都道府県がそろわない',
    CAST(year * 100 + month AS VARCHAR) || ' ' || CAST(COUNT(DISTINCT area) AS VARCHAR)
FROM mart
GROUP BY year, month
HAVING COUNT(DISTINCT area) <> 48 OR COUNT(*) <> 48
    OR COUNT(*) FILTER (WHERE area = '00000') <> 1

UNION ALL

SELECT '都道府県コードが地域コードと合わない', area
FROM (SELECT DISTINCT area, prefecture_code FROM mart)
WHERE NOT (
    (area = '00000' AND prefecture_code IS NULL)
    OR (regexp_matches(area, '^(0[1-9]|[1-3][0-9]|4[0-7])000$') AND prefecture_code = LEFT(area, 2))
)

UNION ALL

SELECT '年度が月と合わない', CAST(year * 100 + month AS VARCHAR)
FROM mart
WHERE fiscal_year <> CASE WHEN month >= 4 THEN year ELSE year - 1 END

UNION ALL

SELECT '合計か小計が NULL か 0 以下', area || ' ' || CAST(year * 100 + month AS VARCHAR)
FROM mart
WHERE total IS NULL OR total <= 0 OR national_total IS NULL OR local_total IS NULL

UNION ALL

SELECT '発注機関の和が小計・合計と合わない', area || ' ' || CAST(year * 100 + month AS VARCHAR)
FROM mart
WHERE ABS(total - national_total - local_total) > 0.01
    OR ABS(national_total - national_government - independent_agency - government_affiliated) > 0.01
    OR ABS(local_total - prefectural_government - municipal_government - local_public_enterprise - other) > 0.01

UNION ALL

SELECT '都道府県の和が全国計と合わない', CAST(n.year * 100 + n.month AS VARCHAR)
FROM nationwide n
JOIN prefecture_sums p USING (year, month)
WHERE ABS(p.total - n.total) > 0.01
    OR ABS(p.national_total - n.national_total) > 0.01
    OR ABS(p.local_total - n.local_total) > 0.01
    OR ABS(p.national_government - n.national_government) > 0.01
    OR ABS(p.municipal_government - n.municipal_government) > 0.01
