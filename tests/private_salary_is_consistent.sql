-- private_salary.industry_salary_class の整合を検証する。結果が0行ならテスト成功。
--
-- 給与所得者数は標本からの推計値なので、内訳の足し算は丸めの幅を許す。実測の最大ずれは
-- 給与階級の合計と計・業種の合計と合計で4人、男女の合計と計で1人。
-- 給与の総額（百万円）は給料・手当と賞与の和と最大1ずれる（百万円未満の丸め）。
--
-- 表章項目（tab）を列に開く対応を取り違えても行数も型も変わらないので、指標どうしの
-- 関係で押さえる。実測で成り立つもの:
--   平均給与 = 給料・手当の平均 + 賞与の平均（±1千円）
--   総額 × 1000 / 人数 と平均の差は、1万人以上の区分で給料・手当・給与とも0.07%以内
--     （賞与は平均が数千円の区分があり丸めで大きくずれるので見ない）
--   平均給与はその給与階級の区間に入る（境界値の取り違えもこれで落ちる）
--   平均年齢は平均勤続年数より18歳以上大きい（検査は15歳で切る）
--   賞与の総額と平均は同じ行で NULL になる
-- 給与階級の上限は名称の数字と照合し、下限は1つ前の階級の上限と一致する（0万円から隙間なく続く）ことを見る。
--
-- e-Stat 側で分類のコードの意味が入れ替わっても行数は変わらないので、
-- 計・合計のコード（給与階級 15・業種 15・性別 3）が内訳の和になることで固定しておく。
-- 突き合わせだけだと片方が丸ごと消えたときに 0 行で成功してしまうので、
-- 2014年から年が欠けずに並ぶこと、比較できた組が1つも無い場合も落とす。

WITH s AS (
    SELECT * FROM {{ ref('industry_salary_class') }}
),

keys AS (
    SELECT 'duplicate_key' AS check_name, year, industry_code, COUNT(*) AS n
    FROM s
    GROUP BY year, industry_code, salary_class_code, sex_code
    HAVING COUNT(*) > 1
),

by_class AS (
    SELECT
        year, industry_code,
        MAX(earners) FILTER (WHERE salary_class_code = '15') AS total,
        SUM(earners) FILTER (WHERE salary_class_code <> '15') AS parts
    FROM s
    GROUP BY year, industry_code, sex_code
),

by_industry AS (
    SELECT
        year, salary_class_code,
        MAX(earners) FILTER (WHERE industry_code = '15') AS total,
        SUM(earners) FILTER (WHERE industry_code <> '15') AS parts
    FROM s
    GROUP BY year, salary_class_code, sex_code
),

by_sex AS (
    SELECT
        year, industry_code,
        MAX(earners) FILTER (WHERE sex_code = '3') AS total,
        SUM(earners) FILTER (WHERE sex_code <> '3') AS parts
    FROM s
    GROUP BY year, industry_code, salary_class_code
)

SELECT check_name, year, industry_code, n AS difference FROM keys

UNION ALL

SELECT 'salary_class_total_mismatch', year, industry_code, total - parts
FROM by_class
WHERE ABS(total - parts) > 10

UNION ALL

SELECT 'industry_total_mismatch', year, NULL, total - parts
FROM by_industry
WHERE ABS(total - parts) > 10

UNION ALL

SELECT 'sex_total_mismatch', year, industry_code, total - parts
FROM by_sex
WHERE ABS(total - parts) > 10

UNION ALL

SELECT 'pay_total_mismatch', year, industry_code, pay_total - (wages_total + bonus_total)
FROM s
WHERE ABS(pay_total - (wages_total + bonus_total)) > 1

UNION ALL

SELECT 'avg_sum_mismatch', year, industry_code, pay_avg - (wages_avg + COALESCE(bonus_avg, 0))
FROM s
WHERE ABS(pay_avg - (wages_avg + COALESCE(bonus_avg, 0))) > 1

UNION ALL

SELECT 'total_avg_mismatch', year, industry_code, NULL
FROM s
WHERE earners >= 10000
  AND (ABS(wages_total * 1000.0 / earners - wages_avg) > wages_avg * 0.01
    OR ABS(pay_total * 1000.0 / earners - pay_avg) > pay_avg * 0.01)

UNION ALL

SELECT 'pay_avg_out_of_class', year, industry_code, pay_avg
FROM s
WHERE salary_class_code <> '15'
  AND (pay_avg <= salary_class_lower * 10 OR pay_avg > salary_class_upper * 10)

UNION ALL

SELECT 'class_bound_name_mismatch', year, industry_code, salary_class_upper
FROM s
WHERE salary_class_code <> '15'
  AND salary_class_upper IS DISTINCT FROM
      TRY_CAST(replace(regexp_extract(salary_class, '([0-9,]+)万円以下', 1), ',', '') AS INTEGER)

UNION ALL

SELECT 'class_bounds_not_contiguous', NULL, c.salary_class_code, c.salary_class_lower
FROM (SELECT DISTINCT salary_class_code, salary_class_lower FROM s WHERE salary_class_code <> '15') c
LEFT JOIN (SELECT DISTINCT salary_class_code, salary_class_upper FROM s WHERE salary_class_code <> '15') p
    ON CAST(p.salary_class_code AS INTEGER) = CAST(c.salary_class_code AS INTEGER) - 1
WHERE c.salary_class_lower IS DISTINCT FROM COALESCE(p.salary_class_upper, 0)

UNION ALL

SELECT 'age_below_tenure', year, industry_code, avg_age - avg_tenure_years
FROM s
WHERE avg_age < avg_tenure_years + 15

UNION ALL

SELECT 'bonus_null_mismatch', year, industry_code, NULL
FROM s
WHERE (bonus_total IS NULL) <> (bonus_avg IS NULL)

UNION ALL

SELECT 'year_missing', MIN(year), NULL, COUNT(DISTINCT year)
FROM s
HAVING MIN(year) <> 2014 OR COUNT(DISTINCT year) <> MAX(year) - MIN(year) + 1

UNION ALL

SELECT 'no_comparable_rows', NULL, NULL, NULL
FROM by_class
HAVING COUNT(*) FILTER (WHERE total IS NOT NULL AND parts IS NOT NULL) = 0
