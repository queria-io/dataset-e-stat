SELECT
    revision,
    level,
    code,
    name,
    parent_code,
    major_code,
    description
FROM {{ ref('raw_industry_economic_census') }}
