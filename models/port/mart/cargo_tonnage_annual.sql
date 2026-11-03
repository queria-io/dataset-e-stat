SELECT
    area_code,
    area_level,
    prefecture_code,
    prefecture_name,
    port_name,
    flow_code,
    flow_name,
    time,
    year,
    cargo_tons,
    cargo_tons_is_derived,
    general_tons,
    ferry_tons,
    transshipment_tons
FROM {{ ref('stg_port_cargo_tonnage_annual') }}
