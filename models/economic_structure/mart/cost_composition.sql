SELECT
    year,
    business_code,
    business_name,
    cost_item_code,
    cost_scope,
    cost_item,
    share_percent
FROM {{ ref('stg_economic_structure_cost') }}
