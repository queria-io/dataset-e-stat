-- school.enrollment_by_grade の整合を検証する。結果が0行ならテスト成功。
--
-- 行見出しは「青森」「青森県」のような略称で、コードはパイプラインが名前から振っている。
-- 当て違いがあると別の県の値が入ったまま通るので、略称が正式名の先頭と一致することを見る。
--
-- 計と内訳が同じ列に並ぶ表なので、次の4つの足し算がどの年・学校種でもそろう
-- （人数そのものなので丸めの幅は無い）。原典の誤記や、見出しのずれで列や行を
-- 取り違えたときはここで止まる。
-- - 47都道府県の合計 = 全国
-- - 国立 + 公立 + 私立 = 計
-- - 男 + 女 = 男女計（学年の計の行）
-- - 学年の合計 = 学年の計（男・女それぞれ）
--
-- 突き合わせだけだと年が丸ごと消えたときに 0 行で成功してしまうので、
-- 2000年から最新年まで年が連続し、各年に全国+47都道府県 × 4つの設置者 × 学年と性の
-- 組がそろうことも見る。

WITH e AS (
    SELECT * FROM {{ ref('enrollment_by_grade') }}
),

labels AS (
    SELECT DISTINCT area, area_name, area_label
    FROM {{ ref('stg_school_enrollment_by_grade') }}
),

by_area AS (
    SELECT
        year, school_type, founder_code, grade, sex_code,
        MAX(students) FILTER (WHERE area = '00000') AS total,
        SUM(students) FILTER (WHERE area <> '00000') AS parts
    FROM e
    GROUP BY ALL
),

by_founder AS (
    SELECT
        year, school_type, area, grade, sex_code,
        MAX(students) FILTER (WHERE founder_code = '0') AS total,
        SUM(students) FILTER (WHERE founder_code <> '0') AS parts
    FROM e
    GROUP BY ALL
),

by_sex AS (
    SELECT
        year, school_type, founder_code, area,
        MAX(students) FILTER (WHERE sex_code = '0') AS total,
        SUM(students) FILTER (WHERE sex_code <> '0') AS parts
    FROM e
    WHERE grade = 0
    GROUP BY ALL
),

by_grade AS (
    SELECT
        year, school_type, founder_code, area, sex_code,
        MAX(students) FILTER (WHERE grade = 0) AS total,
        SUM(students) FILTER (WHERE grade > 0) AS parts
    FROM e
    WHERE sex_code <> '0'
    GROUP BY ALL
),

shape AS (
    SELECT
        year, school_type, COUNT(*) AS n,
        48 * 4 * CASE school_type WHEN 'elementary' THEN 3 + 6 * 2 ELSE 3 + 3 * 2 END
            AS expected
    FROM e
    GROUP BY ALL
),

years AS (
    SELECT school_type, MIN(year) AS first_year, MAX(year) AS last_year,
        COUNT(DISTINCT year) AS n
    FROM e
    GROUP BY ALL
)

SELECT 'duplicate_key' AS check_name, year, school_type, area, COUNT(*) AS difference
FROM e
GROUP BY year, school_type, founder_code, area, grade, sex_code
HAVING COUNT(*) > 1

UNION ALL
SELECT 'null_students', year, school_type, area, NULL
FROM e
WHERE students IS NULL OR students < 0

UNION ALL
SELECT 'label_mismatch', NULL, area_label, area, NULL
FROM labels
WHERE NOT starts_with(area_name, area_label)

UNION ALL
SELECT 'prefectures_sum_to_national', year, school_type, NULL, parts - total
FROM by_area
WHERE parts IS DISTINCT FROM total

UNION ALL
SELECT 'founders_sum_to_total', year, school_type, area, parts - total
FROM by_founder
WHERE parts IS DISTINCT FROM total

UNION ALL
SELECT 'sexes_sum_to_total', year, school_type, area, parts - total
FROM by_sex
WHERE parts IS DISTINCT FROM total

UNION ALL
SELECT 'grades_sum_to_total', year, school_type, area, parts - total
FROM by_grade
WHERE parts IS DISTINCT FROM total

UNION ALL
SELECT 'row_count', year, school_type, NULL, n - expected
FROM shape
WHERE n <> expected

UNION ALL
SELECT 'year_gap', last_year, school_type, NULL, n - (last_year - 2000 + 1)
FROM years
WHERE first_year <> 2000 OR n <> last_year - 2000 + 1

UNION ALL
SELECT 'school_types_disagree', NULL, NULL, NULL, COUNT(DISTINCT last_year)
FROM years
HAVING COUNT(*) <> 2 OR COUNT(DISTINCT last_year) <> 1
