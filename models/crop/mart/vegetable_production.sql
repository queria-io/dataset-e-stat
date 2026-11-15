SELECT
    year,
    crop,
    season,
    subset,
    area,
    area_name,
    prefecture_code,
    planted_area_ha,
    yield_kg_per_10a,
    harvest_t,
    shipment_t
FROM {{ ref('stg_crop_vegetable_prefecture') }}
