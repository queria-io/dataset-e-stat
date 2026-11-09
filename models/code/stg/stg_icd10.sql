SELECT
    revision,
    level,
    code,
    name,
    parent_code,
    chapter_code
FROM {{ ref('raw_icd10') }}
