SELECT
    fiscal_year,
    entity_category_code,
    area_code,
    lg_code,
    pref_name,
    entity_name,
    fiscal_capacity_index,
    standard_fiscal_scale,
    standard_tax_revenue,
    standard_revenue,
    standard_demand,
    extraordinary_bond_limit
FROM {{ ref('stg_local_finance_capacity') }}
