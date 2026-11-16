-- 原典の行見出しは 1〜47 の番号と「青　森」のような略称。都道府県名は mart で当てる。
SELECT
    w.survey_year AS year,
    w.area,
    w.area_name AS area_label,
    w.prefecture_code,
    w.industry_code,
    w.industry,
    w.sex_code,
    w.sex,
    w.scheduled_earnings,
    w.annual_special_earnings
FROM {{ ref('raw_wage_structure_prefecture_industry') }} w
