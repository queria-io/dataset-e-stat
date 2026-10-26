-- 令和7年国勢調査の市区町村別の表 (census_municipality_2025・census_municipality_age_2025)
-- の整合を検証する。結果が0行ならテスト成功。
--
-- 1. area_level が全行に付いている (e-Stat が新しい level を配ると NULL が混ざる)
-- 2. 全国行に全項目がある (表章事項コードが振り直されると列が丸ごと NULL になる)
-- 3. prefecture だけ、city + town_village だけの合計がそれぞれ全国に一致する
-- 4. 年齢の 22 区分 (5歳階級と不詳) の合計が、地域ごとに人口に一致する
-- 5. 比べる相手の 2020年の人口が、全国で令和2年の census_municipality と一致する

WITH m AS (
    SELECT * FROM {{ ref('census_municipality_2025') }}
),

age AS (
    SELECT area, SUM(population) AS population, COUNT(*) AS classes
    FROM {{ ref('census_municipality_age_2025') }}
    GROUP BY area
),

totals AS (
    SELECT
        SUM(population) FILTER (WHERE area_level = 'national') AS national,
        SUM(population) FILTER (WHERE area_level = 'prefecture') AS prefecture,
        SUM(population) FILTER (WHERE area_level IN ('city', 'town_village')) AS municipality
    FROM m
)

SELECT 'area_level is null' AS failure, area FROM m WHERE area_level IS NULL
UNION ALL
SELECT 'age area_level is null', area
FROM {{ ref('census_municipality_age_2025') }} WHERE area_level IS NULL
UNION ALL
SELECT 'national measure is null', area
FROM m
WHERE area_level = 'national'
  AND (
    population IS NULL OR population_male IS NULL OR population_female IS NULL
    OR households IS NULL OR households_general IS NULL OR households_institutional IS NULL
    OR household_members IS NULL OR household_members_general IS NULL
    OR household_members_institutional IS NULL
    OR population_2020 IS NULL OR households_2020 IS NULL
    OR population_change_5y IS NULL OR population_change_rate_5y IS NULL
    OR household_change_5y IS NULL OR household_change_rate_5y IS NULL
    OR sex_ratio IS NULL OR area_km2 IS NULL OR population_density IS NULL
  )
UNION ALL
SELECT 'levels do not add up to national', NULL
FROM totals
WHERE prefecture <> national OR municipality <> national
UNION ALL
SELECT 'age classes do not add up to population', m.area
FROM m
LEFT JOIN age ON m.area = age.area
WHERE age.classes IS DISTINCT FROM 22
   OR age.population IS DISTINCT FROM m.population
UNION ALL
SELECT 'population_2020 differs from census_municipality', m.area
FROM m
JOIN {{ ref('census_municipality') }} c2020
    ON m.area = c2020.area AND c2020.area_level = 'national'
WHERE m.population_2020 <> c2020.population
