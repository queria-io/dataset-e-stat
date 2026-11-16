-- 行見出しの地域名に標準地域コードを当てる。
--
-- 都道府県は正式名で、今の都道府県の名前に当てる。市の行は指定都市と中核市。
-- 今の市区町村と政令指定都市の名前に当てる (welfare_facility と同じ当て方)。
WITH prefecture AS (
    SELECT area_code, pref_code, pref_name
    FROM {{ ref('current_area') }}
    WHERE area_kind = 'prefecture'
),

city AS (
    SELECT
        area_code,
        pref_code,
        pref_name,
        name AS city_name
    FROM {{ ref('current_area') }}
    WHERE area_kind <> 'prefecture'
)

SELECT
    n.survey_year,
    CASE WHEN n.area_kind = 'nationwide' THEN '00000'
        ELSE COALESCE(p.area_code, c.area_code)
    END AS area_code,
    n.area_name,
    n.area_kind,
    COALESCE(p.pref_code, c.pref_code) AS prefecture_code,
    COALESCE(p.pref_name, c.pref_name) AS prefecture_name,
    n.service_category,
    n.service_type,
    n.value
FROM {{ ref('stg_kaigo_service_establishment') }} n
LEFT JOIN prefecture p ON n.area_kind = 'prefecture' AND p.pref_name = n.area_name
LEFT JOIN city c
    ON n.area_kind IN ('designated_city', 'core_city')
    AND c.city_name = n.area_name
