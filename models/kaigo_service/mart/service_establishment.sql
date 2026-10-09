SELECT
    survey_year,
    area_code,
    area_name,
    area_kind,
    prefecture_code,
    prefecture_name,
    service_category,
    service_type,
    value
FROM {{ ref('stg_kaigo_service_establishment') }}
