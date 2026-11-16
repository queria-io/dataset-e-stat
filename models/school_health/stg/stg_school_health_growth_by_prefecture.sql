-- コードに名称を付ける。
--
-- 原典の行見出しは「青森」「青森県」と年度によって揺れる略称で、コードはパイプラインが
-- 名前から振っている。都道府県名は mart で標準地域コードの一覧から当てる。名前の当て違いが無いことは tests/school_health_is_consistent.sql で
-- 略称と正式名を突き合わせて確かめる。
SELECT
    s.survey_year AS year,
    s.age,
    s.sex_code,
    CASE s.sex_code
        WHEN '1' THEN '男'
        WHEN '2' THEN '女'
    END AS sex,
    s.area,
    s.area_label,
    s.prefecture_code,
    s.height_mean,
    s.height_sd,
    s.weight_mean,
    s.weight_sd,
    s.sitting_height_mean,
    s.sitting_height_sd
FROM {{ ref('raw_school_health_growth_by_prefecture') }} s
