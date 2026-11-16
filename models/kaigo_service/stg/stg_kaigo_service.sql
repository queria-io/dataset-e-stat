SELECT
    survey_year,
    area_code,
    area_name,
    area_kind,
    prefecture_code,
    facility_type,
    survey_form,
    measure,
    value
FROM {{ ref('raw_kaigo_service') }}
