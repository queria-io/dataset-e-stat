SELECT
    revision,
    level,
    code,
    name,
    parent_code,
    major_code,
    description
FROM {{ ref('stg_industry_economic_census') }}
