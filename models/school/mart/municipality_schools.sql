SELECT
    r.survey_year AS year,
    r.school_type,
    CASE r.school_type WHEN 'elementary' THEN '小学校' WHEN 'junior_high' THEN '中学校' END AS school_type_name,
    a.area,
    a.area_name,
    a.area_level,
    a.prefecture_code,
    a.city_code,
    r.founder,
    r.founder_detail,
    r.campus,
    r.value AS schools
FROM {{ ref('raw_school_municipality_schools') }} r
JOIN {{ ref('stg_school_municipality_area') }} a
    ON a.prefecture_name = r.prefecture_name
    AND a.municipality_code IS NOT DISTINCT FROM r.municipality_code
    AND a.municipality_name IS NOT DISTINCT FROM r.municipality_name
