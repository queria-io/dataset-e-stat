-- 行見出しの地域名に標準地域コードを当てる。
--
-- 都道府県は 2023 年調査まで「青森」、2024 年調査から「青森県」で入る。接尾辞を
-- 補って code.municipality の pref_name にそろえる。東京・大阪・京都は「都」
-- 「府」で終わるので、末尾 1 文字で判定する前に名指しで拾う。
--
-- 市の行は指定都市と中核市。指定都市は code.municipality で municipality_name が
-- NULL・district_name が市名の行なので、両方を COALESCE で一本にして突き合わせる
-- (welfare_facility と同じ当て方)。
WITH named AS (
    SELECT
        *,
        CASE
            WHEN area_kind <> 'prefecture' THEN area_name
            WHEN area_name = '東京' THEN '東京都'
            WHEN area_name IN ('大阪', '京都') THEN area_name || '府'
            WHEN right(area_name, 1) IN ('都', '道', '府', '県') THEN area_name
            ELSE area_name || '県'
        END AS full_name
    FROM {{ ref('raw_kaigo_service_establishment') }}
),

prefecture AS (
    SELECT area_code, pref_code, pref_name
    FROM {{ ref('stg_municipality') }}
    WHERE is_prefecture
),

city AS (
    SELECT
        area_code,
        pref_code,
        pref_name,
        COALESCE(municipality_name, district_name) AS city_name
    FROM {{ ref('stg_municipality') }}
    WHERE NOT is_prefecture
        AND (municipality_name IS NOT NULL OR district_name LIKE '%市')
)

SELECT
    n.survey_year,
    CASE WHEN n.area_kind = 'nationwide' THEN '00000'
        ELSE COALESCE(p.area_code, c.area_code)
    END AS area_code,
    n.full_name AS area_name,
    n.area_kind,
    COALESCE(p.pref_code, c.pref_code) AS prefecture_code,
    COALESCE(p.pref_name, c.pref_name) AS prefecture_name,
    n.service_category,
    n.service_type,
    n.value
FROM named n
LEFT JOIN prefecture p ON n.area_kind = 'prefecture' AND p.pref_name = n.full_name
LEFT JOIN city c
    ON n.area_kind IN ('designated_city', 'core_city')
    AND c.city_name = n.full_name
