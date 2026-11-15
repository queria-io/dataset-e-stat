SELECT
    stats_data_id,
    class_id,
    class_name,
    class_description,
    item_code,
    item_name,
    level,
    unit,
    parent_code,
    add_inf
FROM {{ ref('raw_meta_info') }}
