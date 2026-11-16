-- 行見出しの地域名に標準地域コードを当てる。
--
-- 都道府県は正式名で、今の都道府県の名前に当てる。市の行は指定都市と中核市。
-- 今の市区町村と政令指定都市の名前に当てる
-- (実測: 2011〜2017 年調査に出る 68 市がすべて 1 件で解決する)。
WITH prefecture AS (
    SELECT area_code, pref_code, pref_name
    FROM {{ ref('current_area') }}
    WHERE area_kind = 'prefecture'
),

city AS (
    SELECT
        area_code,
        pref_code,
        name AS city_name
    FROM {{ ref('current_area') }}
    WHERE area_kind <> 'prefecture'
)

SELECT
    n.survey_year,
    n.area_kind,
    COALESCE(p.area_code, c.area_code) AS area_code,
    n.area_name,
    COALESCE(p.pref_code, c.pref_code) AS prefecture_code,
    n.facility_code,
    n.facility_type,
    n.facility_parent,
    n.facility_group,
    n.facility_level,
    n.operator,
    n.survey_form,
    n.measure,
    n.value
FROM {{ ref('stg_welfare_facility') }} n
LEFT JOIN prefecture p ON n.area_kind = 'prefecture' AND p.pref_name = n.area_name
LEFT JOIN city c
    ON n.area_kind IN ('designated_city', 'core_city')
    AND c.city_name = n.area_name
