SELECT
    year,
    industry_code,
    industry_name,
    industry_level,
    organization_code,
    organization,
    measure_code,
    measure,
    unit,
    value
FROM {{ ref('stg_economic_structure_enterprise') }}
