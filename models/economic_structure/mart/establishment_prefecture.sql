SELECT
    year,
    area,
    area_name,
    area_level,
    industry_code,
    industry_name,
    industry_level,
    establishments,
    sales_million_yen
FROM {{ ref('stg_economic_structure_establishment') }}
