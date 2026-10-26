{# 令和7年国勢調査の男女・5歳階級別人口を、地域 × 年齢階級 1 行に開く。
   年齢の総数(00)と再掲(R1〜R6)は落とし、5歳階級 21 区分と年齢不詳(22)だけ残す。
   残した 22 区分を足すと census_municipality_2025 の population に一致する。
   国籍は総数と「うち日本人」を列に分ける。 #}
SELECT
    area,
    ANY_VALUE(area_name) AS area_name,
    ANY_VALUE(area_level) AS area_level,
    ANY_VALUE(parent_area) AS parent_area,
    age_code,
    ANY_VALUE(age_class) AS age_class,
    CASE
        WHEN age_code BETWEEN '01' AND '21' THEN (CAST(age_code AS INTEGER) - 1) * 5
    END AS age_from,
    CASE
        WHEN age_code BETWEEN '01' AND '20' THEN CAST(age_code AS INTEGER) * 5 - 1
    END AS age_to,
    MAX(value) FILTER (WHERE nationality_code = '0' AND sex_code = '0') AS population,
    MAX(value) FILTER (WHERE nationality_code = '0' AND sex_code = '1') AS population_male,
    MAX(value) FILTER (WHERE nationality_code = '0' AND sex_code = '2') AS population_female,
    MAX(value) FILTER (WHERE nationality_code = '1' AND sex_code = '0') AS population_japanese,
    MAX(value) FILTER (WHERE nationality_code = '1' AND sex_code = '1') AS population_japanese_male,
    MAX(value) FILTER (WHERE nationality_code = '1' AND sex_code = '2') AS population_japanese_female
FROM {{ ref('stg_census_2025_municipality_age') }}
WHERE age_code BETWEEN '01' AND '22'
GROUP BY area, age_code
