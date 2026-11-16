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
    s.sex_code,
    s.sex,
    s.age,
    s.tenure_years,
    s.scheduled_hours,
    s.overtime_hours,
    s.contractual_earnings,
    s.scheduled_earnings,
    s.annual_special_earnings,
    s.workers
FROM {{ ref('stg_wage_structure_prefecture') }} s
LEFT JOIN prefecture p ON p.pref_code = s.prefecture_code
