-- 都道府県名を標準地域コードの一覧から当てる。原典の行見出しは 1〜47 の番号と
-- 「青　森」のような略称。
WITH prefecture AS (
    SELECT pref_code, pref_name
    FROM {{ ref('stg_municipality') }}
    WHERE is_prefecture
)

SELECT
    w.survey_year AS year,
    w.area,
    COALESCE(p.pref_name, w.area_name) AS area_name,
    w.area_name AS area_label,
    w.prefecture_code,
    w.industry_code,
    w.industry,
    w.sex_code,
    w.sex,
    w.scheduled_earnings,
    w.annual_special_earnings
FROM {{ ref('raw_wage_structure_prefecture_industry') }} w
LEFT JOIN prefecture p ON p.pref_code = w.prefecture_code
