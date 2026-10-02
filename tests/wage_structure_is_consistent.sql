-- wage_structure の2表の整合を検証する。結果が0行ならテスト成功。
--
-- 参考表1 は行見出しが都道府県の略称だけで、コードはパイプラインが並び順から振っている。
-- 並びがずれると別の県の値が入ったまま通るので、略称が正式名の先頭と一致することを見る
-- （「青森」と「青森県」、「北海道」と「北海道」）。参考表2 は番号と略称の両方がある。
--
-- 労働者数は原典が十人単位なので、内訳の足し算は丸めの幅を許す。実測の最大ずれは
-- 男と女の合計と男女計で10人、47都道府県の合計と全国で50人。
--
-- 足し算の検査は NULL の行を飛ばすので、NULL の出方も固定する。prefecture_wage には
-- NULL が無く、prefecture_industry_wage では原典が「-」の鉱業，採石業，砂利採取業（C）だけが
-- 2指標そろって欠ける。秘匿記号や見出しのずれで値が落ちたときはここで止まる。
--
-- 突き合わせだけだと片方の年が丸ごと消えたときに 0 行で成功してしまうので、
-- 2020年から最新年まで年が連続し、各年に全国+47都道府県 × 3つの性がそろうことも見る。

WITH p AS (
    SELECT * FROM {{ ref('prefecture_wage') }}
),

i AS (
    SELECT * FROM {{ ref('prefecture_industry_wage') }}
),

labels AS (
    SELECT 'prefecture_wage' AS t, year, area, area_name, area_label
    FROM {{ ref('stg_wage_structure_prefecture') }}
    UNION ALL
    SELECT 'prefecture_industry_wage', year, area, area_name, area_label
    FROM {{ ref('stg_wage_structure_prefecture_industry') }}
),

by_sex AS (
    SELECT
        year, area,
        MAX(workers) FILTER (WHERE sex_code = '0') AS total,
        MAX(workers) FILTER (WHERE sex_code = '1') AS male,
        MAX(workers) FILTER (WHERE sex_code = '2') AS female
    FROM p
    GROUP BY year, area
),

by_area AS (
    SELECT
        year, sex_code,
        MAX(workers) FILTER (WHERE area = '00000') AS national,
        SUM(workers) FILTER (WHERE area <> '00000') AS prefectures
    FROM p
    GROUP BY year, sex_code
),

shape AS (
    SELECT 'prefecture_wage' AS t, year, COUNT(*) AS n, 48 * 3 AS expected
    FROM p GROUP BY year
    UNION ALL
    SELECT 'prefecture_industry_wage', year, COUNT(*), 48 * 16 * 3
    FROM i GROUP BY year
)

SELECT 'duplicate_key' AS check_name, year, area, COUNT(*) AS difference
FROM p
GROUP BY year, area, sex_code
HAVING COUNT(*) > 1

UNION ALL

SELECT 'duplicate_key', year, area, COUNT(*)
FROM i
GROUP BY year, area, industry_code, sex_code
HAVING COUNT(*) > 1

UNION ALL

SELECT 'prefecture_label_mismatch', year, area, NULL
FROM labels
WHERE area <> '00000' AND NOT starts_with(area_name, area_label)

UNION ALL

SELECT 'shape_mismatch', year, t, n - expected
FROM shape
WHERE n <> expected

UNION ALL

SELECT 'sex_total_mismatch', year, area, total - (male + female)
FROM by_sex
WHERE ABS(total - (male + female)) > 10

UNION ALL

SELECT 'area_total_mismatch', year, sex_code, national - prefectures
FROM by_area
WHERE ABS(national - prefectures) > 50

UNION ALL

SELECT 'unexpected_null', year, area, NULL
FROM p
WHERE age IS NULL OR tenure_years IS NULL OR scheduled_hours IS NULL OR overtime_hours IS NULL
   OR contractual_earnings IS NULL OR scheduled_earnings IS NULL
   OR annual_special_earnings IS NULL OR workers IS NULL

UNION ALL

SELECT 'unexpected_null', year, area, NULL
FROM i
WHERE (scheduled_earnings IS NULL OR annual_special_earnings IS NULL)
  AND (industry_code <> 'C' OR (scheduled_earnings IS NULL) <> (annual_special_earnings IS NULL))

UNION ALL

SELECT 'scheduled_exceeds_contractual', year, area, scheduled_earnings - contractual_earnings
FROM p
WHERE scheduled_earnings > contractual_earnings

UNION ALL

SELECT 'year_missing', NULL, NULL, COUNT(DISTINCT year)
FROM p
HAVING MIN(year) <> 2020 OR COUNT(DISTINCT year) <> MAX(year) - MIN(year) + 1

UNION ALL

SELECT 'year_mismatch_between_tables', NULL, NULL, NULL
FROM (SELECT DISTINCT year FROM p) a
FULL JOIN (SELECT DISTINCT year FROM i) b ON a.year = b.year
WHERE a.year IS NULL OR b.year IS NULL

UNION ALL

SELECT 'no_comparable_rows', NULL, NULL, NULL
FROM by_sex
HAVING COUNT(*) FILTER (WHERE total IS NOT NULL AND male IS NOT NULL AND female IS NOT NULL) = 0
