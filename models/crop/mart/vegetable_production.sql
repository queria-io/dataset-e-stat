{# 作付面積・収穫量・出荷量は原典の整数（ha・t）なので BIGINT に戻す。
   10a当たり収量（kg）も整数で公表される。 #}
SELECT
    year,
    crop,
    season,
    subset,
    area,
    area_name,
    prefecture_code,
    CAST(planted_area_ha AS BIGINT) AS planted_area_ha,
    CAST(yield_kg_per_10a AS BIGINT) AS yield_kg_per_10a,
    CAST(harvest_t AS BIGINT) AS harvest_t,
    CAST(shipment_t AS BIGINT) AS shipment_t
FROM {{ ref('raw_crop_vegetable_prefecture') }}
