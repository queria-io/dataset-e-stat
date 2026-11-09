SELECT
    revision,
    level,
    code,
    name,
    parent_code,
    chapter_code
FROM {{ ref('stg_icd10') }}
