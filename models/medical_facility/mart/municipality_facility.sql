{# 1 地域 1 行に開く。項目は病院の表と診療所の表に分かれているが、地域の並びは
   同じ年の 2 表で同じ (実測)。原典に無い年の項目 (結核療養所は 2012 年まで) は NULL。
   静態調査は 3 年ごと (2008・2011・2014・2017・2020・2023 年) で、ほかの年は動態調査。 #}
{% set measures = [
    'hospitals',
    'psychiatric_hospitals',
    'tuberculosis_sanatoriums',
    'general_hospitals',
    'general_hospitals_with_long_term_care_beds',
    'regional_support_hospitals',
    'emergency_hospitals',
    'hospital_beds',
    'psychiatric_beds',
    'infectious_beds',
    'tuberculosis_beds',
    'long_term_care_beds',
    'general_beds',
    'regional_support_hospital_beds',
    'general_clinics',
    'general_clinics_with_beds',
    'general_clinics_with_long_term_care_beds',
    'general_clinics_without_beds',
    'general_clinic_beds',
    'general_clinic_long_term_care_beds',
    'dental_clinics',
    'dental_clinics_with_beds',
    'dental_clinics_without_beds'
] %}
SELECT
    survey_year,
    CASE WHEN (survey_year - 2008) % 3 = 0 THEN 'static' ELSE 'dynamic' END AS survey_kind,
    area_level,
    area_code,
    area_name,
    prefecture_code,
    medical_area_code,
    medical_area_name,
    {%- for m in measures %}
    CAST(MAX(value) FILTER (WHERE measure = '{{ m }}') AS BIGINT) AS {{ m }}{{ ',' if not loop.last }}
    {%- endfor %}
FROM {{ ref('stg_medical_facility') }}
GROUP BY ALL
