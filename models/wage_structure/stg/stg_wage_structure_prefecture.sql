-- 都道府県名を標準地域コードの一覧から当てる。
--
-- 原典の行見出しは「青　森」のような略称で、参考表1 にはコードが無い
-- (パイプラインが全国の次から JIS 順に 01〜47 を振っている)。並びが崩れていないことは
-- tests/wage_structure_is_consistent.sql で略称と正式名を突き合わせて確かめる。
--
-- 労働者数は原典が十人単位なので人に直す。
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
    w.sex_code,
    w.sex,
    w.age,
    w.tenure_years,
    w.scheduled_hours,
    w.overtime_hours,
    w.contractual_earnings,
    w.scheduled_earnings,
    w.annual_special_earnings,
    w.workers * 10 AS workers
FROM {{ ref('raw_wage_structure_prefecture') }} w
LEFT JOIN prefecture p ON p.pref_code = w.prefecture_code
