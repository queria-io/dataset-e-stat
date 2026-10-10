-- school_health.growth_by_prefecture の整合を検証する。結果が0行ならテスト成功。
--
-- 行見出しは「青森」「青森県」のような略称で、コードはパイプラインが名前から振っている。
-- 当て違いがあると別の県の値が入ったまま通るので、略称が正式名の先頭と一致することを見る。
--
-- 平均値は足し算の関係を持たないので、次の形で列や行の取り違えを捕まえる。
-- - 全国の平均値は47都道府県の平均値の最小と最大の間にある
-- - 値が身長・体重・座高として取りうる範囲にある（列を取り違えると桁が外れる）
-- - NULL になるのは、座高の2016年度以降と、2011年度の岩手・宮城・福島（未調査）だけ
--
-- 突き合わせだけだと年度が丸ごと消えたときに 0 行で成功してしまうので、
-- 1996年度から最新年度まで年度が連続し、各年度に 13年齢 × 男女 × 全国+47都道府県 が
-- そろうことも見る。

WITH g AS (
    SELECT * FROM {{ ref('growth_by_prefecture') }}
),

labels AS (
    SELECT DISTINCT area, area_name, area_label
    FROM {{ ref('stg_school_health_growth_by_prefecture') }}
),

prefecture_range AS (
    SELECT
        year, age, sex_code,
        MIN(height_mean) AS height_min, MAX(height_mean) AS height_max,
        MIN(weight_mean) AS weight_min, MAX(weight_mean) AS weight_max
    FROM g
    WHERE area <> '00000'
    GROUP BY ALL
),

unsurveyed AS (
    SELECT *, year = 2011 AND area IN ('03000', '04000', '07000') AS is_unsurveyed
    FROM g
),

shape AS (
    SELECT year, COUNT(*) AS n
    FROM g
    GROUP BY ALL
),

years AS (
    SELECT MIN(year) AS first_year, MAX(year) AS last_year, COUNT(DISTINCT year) AS n
    FROM g
)

SELECT 'duplicate_key' AS check_name, year, area, COUNT(*) AS difference
FROM g
GROUP BY year, age, sex_code, area
HAVING COUNT(*) > 1

UNION ALL
SELECT 'label_mismatch', NULL, area, NULL
FROM labels
WHERE NOT starts_with(area_name, area_label)

UNION ALL
SELECT 'national_outside_prefectures', g.year, g.area, NULL
FROM g
JOIN prefecture_range p USING (year, age, sex_code)
WHERE g.area = '00000'
    AND (g.height_mean NOT BETWEEN p.height_min AND p.height_max
        OR g.weight_mean NOT BETWEEN p.weight_min AND p.weight_max)

UNION ALL
SELECT 'value_out_of_range', year, area, NULL
FROM g
WHERE height_mean NOT BETWEEN 95 AND 185
    OR weight_mean NOT BETWEEN 14 AND 80
    OR sitting_height_mean NOT BETWEEN 55 AND 100
    OR height_sd NOT BETWEEN 2 AND 12
    OR weight_sd NOT BETWEEN 1 AND 20
    OR sitting_height_sd NOT BETWEEN 1 AND 8

UNION ALL
SELECT 'unexpected_null', year, area, NULL
FROM unsurveyed
WHERE NOT is_unsurveyed
    AND (height_mean IS NULL OR height_sd IS NULL
        OR weight_mean IS NULL OR weight_sd IS NULL
        OR (year <= 2015 AND (sitting_height_mean IS NULL OR sitting_height_sd IS NULL)))

UNION ALL
SELECT 'unexpected_value', year, area, NULL
FROM unsurveyed
WHERE (is_unsurveyed AND COALESCE(height_mean, height_sd, weight_mean, weight_sd,
        sitting_height_mean, sitting_height_sd) IS NOT NULL)
    OR (year > 2015 AND COALESCE(sitting_height_mean, sitting_height_sd) IS NOT NULL)

UNION ALL
SELECT 'row_count', year, NULL, n - 13 * 2 * 48
FROM shape
WHERE n <> 13 * 2 * 48

UNION ALL
SELECT 'year_gap', last_year, NULL, n - (last_year - 1996 + 1)
FROM years
WHERE first_year <> 1996 OR n <> last_year - 1996 + 1
