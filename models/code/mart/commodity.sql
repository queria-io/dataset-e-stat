SELECT
    revision,
    level,
    code,
    name,
    parent_code
FROM {{ ref('stg_commodity') }}
