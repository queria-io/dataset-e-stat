-- employment_structure.employment_status の整合を検証する。結果が0行ならテスト成功。
--
-- 値は百人単位に丸めた推定値なので、内訳の足し算は丸めの幅を許す。実測の最大ずれは
-- 男女の合計と総数で100人、年齢階級の合計と総数で200人。
--
-- 就業状態は「うち」の入れ子（総数 ⊃ 有業者 ⊃ 雇用者 ⊃ 正規／非正規 ⊃ パート・アルバイト）。
-- e-Stat 側でコードの意味が入れ替わっても行数も level も変わらないので、
-- 入れ子の大小関係をコードで固定しておく。
--
-- 突き合わせだけだと片方が丸ごと消えたときに 0 行で成功してしまうので、
-- 調査年が2つそろうこと、比較できた組が1つも無い場合も落とす。

WITH s AS (
    SELECT * FROM {{ ref('employment_status') }}
),

keys AS (
    SELECT 'duplicate_key' AS check_name, year, area, COUNT(*) AS n
    FROM s
    GROUP BY year, area, sex_code, marital_status_code, education_code, status_code, age_class_code
    HAVING COUNT(*) > 1
),

by_sex AS (
    SELECT
        year, area,
        MAX(value) FILTER (WHERE sex_code = '0') AS total,
        MAX(value) FILTER (WHERE sex_code = '1') AS male,
        MAX(value) FILTER (WHERE sex_code = '2') AS female
    FROM s
    GROUP BY year, area, marital_status_code, education_code, status_code, age_class_code
),

by_age AS (
    SELECT
        year, area,
        MAX(value) FILTER (WHERE age_class_code = '0') AS total,
        SUM(value) FILTER (WHERE age_class_code <> '0') AS parts,
        COUNT(value) FILTER (WHERE age_class_code <> '0') AS n_parts
    FROM s
    GROUP BY year, area, sex_code, marital_status_code, education_code, status_code
),

by_status AS (
    SELECT
        year, area,
        MAX(value) FILTER (WHERE status_code = '0') AS total,
        MAX(value) FILTER (WHERE status_code = '1') AS employed,
        MAX(value) FILTER (WHERE status_code = '11') AS employees,
        MAX(value) FILTER (WHERE status_code = '111') AS regular,
        MAX(value) FILTER (WHERE status_code = '112') AS non_regular,
        MAX(value) FILTER (WHERE status_code = '1121') AS part_time
    FROM s
    GROUP BY year, area, sex_code, marital_status_code, education_code, age_class_code
)

SELECT check_name, year, area, n AS difference FROM keys

UNION ALL

SELECT 'sex_total_mismatch', year, area, total - (male + female)
FROM by_sex
WHERE ABS(total - (male + female)) > 100

UNION ALL

SELECT 'age_total_mismatch', year, area, total - parts
FROM by_age
WHERE n_parts = 4 AND ABS(total - parts) > 200

UNION ALL

SELECT 'status_nesting_violated', year, area, NULL
FROM by_status
WHERE employed > total
   OR employees > employed
   OR regular + non_regular > employees + 100
   OR part_time > non_regular

UNION ALL

SELECT 'year_missing', NULL, NULL, COUNT(DISTINCT year)
FROM s
HAVING COUNT(DISTINCT year) FILTER (WHERE year IN (2017, 2022)) <> 2

UNION ALL

SELECT 'area_kind_unknown', year, area, NULL
FROM s
WHERE area_kind = 'city' AND (area_name IS NULL OR area_name LIKE '%市部')

UNION ALL

SELECT 'no_comparable_rows', NULL, NULL, NULL
FROM by_status
HAVING COUNT(*) FILTER (WHERE regular IS NOT NULL AND non_regular IS NOT NULL AND employees IS NOT NULL) = 0
