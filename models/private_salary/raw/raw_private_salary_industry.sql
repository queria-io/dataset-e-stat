SELECT
    tab, cat01, cat02, cat03, time, value,
    cat01_metadata, cat02_metadata, cat03_metadata, time_metadata
FROM {{ source('estat_source', 'private_salary_industry') }}
