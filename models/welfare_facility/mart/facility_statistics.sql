SELECT
    survey_year,
    area_kind,
    area_code,
    area_name,
    prefecture_code,
    facility_code,
    facility_type,
    facility_parent,
    facility_group,
    facility_level,
    operator,
    survey_form,
    measure,
    value
FROM {{ ref('stg_welfare_facility') }}
