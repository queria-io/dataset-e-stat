SELECT
    r.fiscal_year,
    a.area,
    a.area_name,
    a.prefecture_code,
    r.industry_code,
    r.industry_name,
    r.parent_industry_code,
    r.value AS energy_tj
FROM {{ ref('raw_energy_consumption_industry') }} r
JOIN {{ ref('stg_energy_consumption_prefecture') }} a ON a.label = r.prefecture_name
