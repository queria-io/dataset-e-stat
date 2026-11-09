SELECT
    revision,
    table_kind,
    code,
    name,
    parent_code,
    icd10_codes
FROM {{ ref('stg_icd10_disease') }}
