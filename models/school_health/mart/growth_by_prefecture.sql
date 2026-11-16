-- 都道府県名を標準地域コードの一覧から当てる。全国の行は原典の見出しのまま
WITH prefecture AS (
    SELECT pref_code, pref_name
    FROM {{ ref('current_area') }}
    WHERE area_kind = 'prefecture'
)

SELECT
    s.year,
    s.age,
    s.sex_code,
    s.sex,
    s.area,
    COALESCE(p.pref_name, s.area_label) AS area_name,
    s.prefecture_code,
    s.height_mean,
    s.height_sd,
    s.weight_mean,
    s.weight_sd,
    s.sitting_height_mean,
    s.sitting_height_sd
FROM {{ ref('stg_school_health_growth_by_prefecture') }} s
LEFT JOIN prefecture p ON p.pref_code = s.prefecture_code
