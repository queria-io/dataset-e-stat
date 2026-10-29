-- construction の mart が、原典の構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 地域軸は地方（level=2）と都道府県（level=3）の2段で、北海道だけは都道府県の行が
-- 無く「北海道地方」（00042）の1行しかない。stg で 00042 を北海道（01000）に読み替え、
-- 残りの地方の行を落としている。読み替えが外れると北海道が抜けて46になり、地方の行が
-- 混ざると47を超える。各月に47都道府県がそろうことで両方を押さえる。
--
-- 地方の行は都道府県の和を億円で丸め直したもので、実測の差は最大2億円。県の数より
-- 大きくずれたら、都道府県の所属（parent_code）か値の読み方が崩れている。
--
-- 毎回全量を取り直して置き換える（replace）ので、原典から月が抜けると mart からも抜ける。
-- 2011年4月から最新月までの月がすべてあることを見る。

WITH mart AS (
    SELECT * FROM {{ ref('prefecture_monthly') }}
),

raw AS (
    SELECT * FROM {{ ref('raw_construction_prefecture_monthly') }}
    WHERE tab = '100'
),

months AS (
    SELECT DISTINCT year * 100 + month AS ym FROM mart
),

expected_months AS (
    SELECT YEAR(d) * 100 + MONTH(d) AS ym
    FROM (
        SELECT UNNEST(RANGE(
            DATE '2011-04-01',
            (SELECT MAKE_DATE(MAX(year * 100 + month) // 100, MAX(year * 100 + month) % 100, 1) FROM mart)
                + INTERVAL 1 MONTH,
            INTERVAL 1 MONTH
        )) AS d
    )
),

region_rows AS (
    SELECT area AS region_code, time, value
    FROM raw
    WHERE area_metadata->>'$.level' = '2' AND area <> '00042'
),

region_sums AS (
    SELECT region_code, time, SUM(output) AS output, COUNT(*) AS prefectures
    FROM mart
    WHERE region_code <> '00042'
    GROUP BY region_code, time
)

SELECT '行が無い、または収録が2011年4月から始まっていない' AS violation,
    COALESCE(CAST(min_ym AS VARCHAR), 'empty') AS detail
FROM (SELECT COUNT(*) AS rows, MIN(year * 100 + month) AS min_ym FROM mart)
WHERE rows = 0 OR min_ym <> 201104

UNION ALL

SELECT '収録されていない月がある', CAST(e.ym AS VARCHAR)
FROM expected_months e
LEFT JOIN months m USING (ym)
WHERE m.ym IS NULL

UNION ALL

SELECT '原典の地域×月×表章が一意でない', area || ' ' || time || ' ' || tab
FROM {{ ref('raw_construction_prefecture_monthly') }}
GROUP BY area, time, tab
HAVING COUNT(*) > 1

UNION ALL

SELECT '月に47都道府県がそろわない', time || ' ' || CAST(COUNT(DISTINCT area) AS VARCHAR)
FROM mart
GROUP BY time
HAVING COUNT(DISTINCT area) <> 47 OR COUNT(*) <> 47

UNION ALL

SELECT '都道府県コードが地域コードと合わない', area
FROM (SELECT DISTINCT area, prefecture_code FROM mart)
WHERE NOT regexp_matches(area, '^(0[1-9]|[1-3][0-9]|4[0-7])000$')
    OR prefecture_code <> LEFT(area, 2)

UNION ALL

SELECT '地方が9つでないか、地方名が無い', COALESCE(region_code, 'NULL')
FROM mart
WHERE region_name IS NULL
    OR (SELECT COUNT(DISTINCT region_code) FROM mart) <> 9
GROUP BY region_code

UNION ALL

SELECT '出来高が 0 以下か NULL', area || ' ' || time
FROM mart
WHERE output IS NULL OR output <= 0

UNION ALL

SELECT '地方の値と都道府県の和が丸めの範囲を超えてずれる',
    s.region_code || ' ' || s.time || ' ' || CAST(s.output - r.value AS VARCHAR)
FROM region_sums s
JOIN region_rows r USING (region_code, time)
WHERE ABS(s.output - r.value) > s.prefectures

UNION ALL

SELECT '地方の行に対応する都道府県が無い', r.region_code || ' ' || r.time
FROM region_rows r
LEFT JOIN region_sums s USING (region_code, time)
WHERE s.region_code IS NULL
