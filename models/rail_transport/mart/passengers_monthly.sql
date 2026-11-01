SELECT
    operator_type_code,
    operator_type_name,
    operator_type_level,
    operator_type_parent_code,
    ticket_type_code,
    ticket_type_name,
    time,
    time_name,
    year,
    month,
    passengers
FROM {{ ref('stg_rail_transport_passengers_monthly') }}
