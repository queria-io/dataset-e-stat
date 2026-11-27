-- population_estimates の mart が、原典の構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 全国と47都道府県 × 男女3区分 × 人口の種類2区分が、すべての年にそろう。
-- 男と女の和は男女計と、都道府県の和は全国と、千人の丸めの範囲でしか違わない
-- （実測の最大はそれぞれ1千人・3千人）。日本人人口は総人口を超えない。
-- 毎回全量を取り直して置き換える (replace) ので、原典から年や地域が抜けると mart からも抜ける。

WITH mart AS (
    SELECT * FROM {{ ref('prefecture_population') }}
),

shape AS (
    SELECT year, COUNT(*) AS n, COUNT(DISTINCT area) AS areas
    FROM mart
    GROUP BY year
    HAVING COUNT(*) <> 48 * 3 * 2 OR COUNT(DISTINCT area) <> 48
),

years AS (
    SELECT COUNT(DISTINCT year) AS n FROM mart
),

sex_sum AS (
    SELECT area, year, population_type_code
    FROM (
        SELECT area, year, population_type_code,
            MAX(population) FILTER (WHERE sex_code = '000') AS total,
            MAX(population) FILTER (WHERE sex_code = '001') AS male,
            MAX(population) FILTER (WHERE sex_code = '002') AS female
        FROM mart
        GROUP BY area, year, population_type_code
    )
    WHERE total IS NULL OR ABS(total - (male + female)) > 2
),

pref_sum AS (
    SELECT year, population_type_code, sex_code
    FROM (
        SELECT year, population_type_code, sex_code,
            MAX(population) FILTER (WHERE area_level = 'national') AS national,
            SUM(population) FILTER (WHERE area_level = 'prefecture') AS prefectures
        FROM mart
        GROUP BY year, population_type_code, sex_code
    )
    WHERE national IS NULL OR ABS(national - prefectures) > 6
),

null_values AS (
    SELECT area, year, sex_code, population_type_code
    FROM mart
    WHERE population IS NULL
),

japanese_over_total AS (
    SELECT area, year, sex_code
    FROM (
        SELECT area, year, sex_code,
            MAX(population) FILTER (WHERE population_type_code = '001') AS total,
            MAX(population) FILTER (WHERE population_type_code = '002') AS japanese
        FROM mart
        GROUP BY area, year, sex_code
    )
    WHERE japanese > total
)

SELECT 'shape' AS failure, CAST(year AS VARCHAR) AS detail FROM shape
UNION ALL
SELECT 'years', CAST(n AS VARCHAR) FROM years WHERE n < 8
UNION ALL
SELECT 'sex_sum', area || ' ' || year || ' ' || population_type_code FROM sex_sum
UNION ALL
SELECT 'pref_sum', year || ' ' || population_type_code || ' ' || sex_code FROM pref_sum
UNION ALL
SELECT 'null_value', area || ' ' || year || ' ' || sex_code || ' ' || population_type_code FROM null_values
UNION ALL
SELECT 'japanese_over_total', area || ' ' || year || ' ' || sex_code FROM japanese_over_total
