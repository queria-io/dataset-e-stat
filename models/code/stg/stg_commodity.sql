SELECT
    revision,
    level,
    code,
    name,
    parent_code
FROM {{ ref('raw_commodity') }}
