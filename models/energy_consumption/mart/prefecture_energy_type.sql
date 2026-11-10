SELECT
    r.fiscal_year,
    a.area,
    a.area_name,
    a.prefecture_code,
    r.energy_type,
    r.parent_energy_type,
    r.value AS energy_tj
FROM {{ ref('raw_energy_consumption_energy_type') }} r
JOIN {{ ref('stg_energy_consumption_prefecture') }} a ON a.label = r.prefecture_name
