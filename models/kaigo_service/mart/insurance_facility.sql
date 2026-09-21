SELECT
    survey_year,
    area_code,
    area_name,
    area_kind,
    prefecture_code,
    prefecture_name,
    facility_type,
    survey_form,
    measure,
    value
FROM {{ ref('stg_kaigo_service') }}
