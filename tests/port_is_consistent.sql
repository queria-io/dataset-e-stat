-- port の mart が、原典の構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 都道府県の行（area_level=2）は、その県の甲種港湾（area_level=3）の cargo_tons の和に、
-- 2018年を除くすべての年・輸移出入でちょうど一致する（実測）。原典は輸送形態の計の行を
-- 出さない港が多く、補い方か段の読み方が崩れるとこの恒等式が外れる。
-- 輸移出入の合計（flow_code=100）も、輸出・輸入・移出・移入の和に一致する（実測）。
--
-- 毎回全量を取り直して置き換える（replace）ので、原典から年が抜けると mart からも抜ける。
-- 2010年から最新年まで、2018年を除くすべての年があることを見る。

WITH mart AS (
    SELECT * FROM {{ ref('cargo_tonnage_annual') }}
),

ports AS (
    SELECT prefecture_code, flow_code, time, SUM(cargo_tons) AS cargo_tons
    FROM mart
    WHERE area_level = 3
    GROUP BY prefecture_code, flow_code, time
),

by_flow AS (
    SELECT area_code, time,
        COUNT(*) FILTER (WHERE flow_code = '100') AS total_rows,
        MAX(cargo_tons) FILTER (WHERE flow_code = '100') AS total,
        SUM(cargo_tons) FILTER (WHERE flow_code <> '100') AS parts
    FROM mart
    GROUP BY area_code, time
),

expected_years AS (
    SELECT UNNEST(RANGE(2010, (SELECT MAX(year) FROM mart) + 1)) AS year
)

SELECT '行が無い、または収録が2010年から始まっていない' AS violation,
    COALESCE(CAST(min_year AS VARCHAR), 'empty') AS detail
FROM (SELECT COUNT(*) AS rows, MIN(year) AS min_year FROM mart)
WHERE rows = 0 OR min_year <> 2010

UNION ALL

SELECT '収録されていない年がある', CAST(e.year AS VARCHAR)
FROM expected_years e
LEFT JOIN (SELECT DISTINCT year FROM mart) m USING (year)
WHERE m.year IS NULL AND e.year <> 2018

UNION ALL

SELECT '原典の値が崩れている2018年が入っている', CAST(COUNT(*) AS VARCHAR)
FROM mart
WHERE year = 2018
HAVING COUNT(*) > 0

UNION ALL

SELECT '港 × 輸移出入 × 年で重複がある', area_code || ' ' || flow_code || ' ' || time
FROM mart
GROUP BY area_code, flow_code, time
HAVING COUNT(*) > 1

UNION ALL

SELECT '年ごとの甲種港湾の数が150を下回る', CAST(year AS VARCHAR) || ' ' || CAST(COUNT(*) AS VARCHAR)
FROM mart
WHERE area_level = 3 AND flow_code = '100' AND cargo_tons IS NOT NULL
GROUP BY year
HAVING COUNT(*) < 150

UNION ALL

SELECT '段と港名・コードの対応が想定と違う', area_code
FROM mart
WHERE NOT (
    (area_level = 2 AND port_name IS NULL AND SUBSTR(area_code, 3) = '000')
    OR (area_level = 3 AND port_name IS NOT NULL AND port_name <> '' AND SUBSTR(area_code, 3) <> '000')
)
OR prefecture_code IS DISTINCT FROM SUBSTR(area_code, 1, 2)

UNION ALL

SELECT '輸移出入のコードが想定と違う', flow_code
FROM mart
WHERE flow_code NOT IN ('100', '110', '120', '130', '140')

UNION ALL

SELECT '負のトン数がある', area_code || ' ' || flow_code || ' ' || time
FROM mart
WHERE cargo_tons < 0 OR general_tons < 0 OR ferry_tons < 0 OR transshipment_tons < 0

UNION ALL

SELECT 'T/S が一般貨物を上回る', area_code || ' ' || flow_code || ' ' || time
FROM mart
WHERE transshipment_tons > general_tons

UNION ALL

SELECT '都道府県の行が港の和に一致しない', r.area_code || ' ' || r.flow_code || ' ' || r.time
FROM mart r
LEFT JOIN ports p USING (prefecture_code, flow_code, time)
WHERE r.area_level = 2 AND r.cargo_tons IS DISTINCT FROM p.cargo_tons

UNION ALL

SELECT '輸移出入の合計が内訳の和に一致しない', area_code || ' ' || time
FROM by_flow
WHERE total_rows > 0 AND total IS DISTINCT FROM parts
