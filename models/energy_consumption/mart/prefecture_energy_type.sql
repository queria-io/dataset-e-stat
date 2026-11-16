SELECT
    r.fiscal_year,
    a.area,
    a.area_name,
    a.prefecture_code,
    r.energy_type,
    r.parent_energy_type,
    r.value AS energy_tj
FROM {{ ref('stg_energy_consumption_energy_type') }} r
JOIN {{ ref('energy_consumption_area') }} a ON a.label = r.prefecture_name
