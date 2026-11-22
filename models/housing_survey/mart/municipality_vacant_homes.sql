SELECT
    area,
    area_name,
    area_level,
    parent_area,
    vacancy_type_code,
    vacancy_type,
    decay_code,
    decay,
    building_type_code,
    building_type,
    structure_code,
    structure,
    vacant_homes
FROM {{ ref('stg_housing_survey_vacant_homes') }}
