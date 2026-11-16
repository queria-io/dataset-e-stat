SELECT * EXCLUDE (_dlt_load_id, _dlt_id)
FROM {{ source('estat_source', 'stats_list') }}
