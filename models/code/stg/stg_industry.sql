SELECT
    revision,
    level,
    code,
    name,
    parent_code,
    major_code,
    description,
    examples,
    non_examples
FROM {{ ref('raw_industry') }}
