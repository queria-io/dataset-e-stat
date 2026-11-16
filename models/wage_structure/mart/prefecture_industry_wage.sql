-- 都道府県名を標準地域コードの一覧から当てる。全国の行は原典の見出しのまま
WITH prefecture AS (
    SELECT pref_code, pref_name
    FROM {{ ref('current_area') }}
    WHERE area_kind = 'prefecture'
)

SELECT
    s.year,
    s.area,
    COALESCE(p.pref_name, s.area_label) AS area_name,
    s.prefecture_code,
    s.industry_code,
    s.industry,
    s.sex_code,
    s.sex,
    s.scheduled_earnings,
    s.annual_special_earnings
FROM {{ ref('stg_wage_structure_prefecture_industry') }} s
LEFT JOIN prefecture p ON p.pref_code = s.prefecture_code
