SELECT
    revision,
    code,
    name,
    parent_code,
    icd10_codes
FROM {{ ref('raw_icd10_cause_of_death') }}
