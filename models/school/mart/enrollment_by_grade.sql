SELECT
    year,
    school_type,
    school_type_name,
    founder_code,
    founder,
    area,
    area_name,
    prefecture_code,
    grade,
    sex_code,
    sex,
    students
FROM {{ ref('stg_school_enrollment_by_grade') }}
