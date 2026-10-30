SELECT
    prefecture_code,
    area,
    area_name,
    year,
    month,
    fiscal_year,
    total,
    national_total,
    national_government,
    independent_agency,
    government_affiliated,
    local_total,
    prefectural_government,
    municipal_government,
    local_public_enterprise,
    other
FROM {{ ref('stg_construction_public_orders_prefecture_monthly') }}
