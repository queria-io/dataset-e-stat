{# e-Stat「市区町村を探す」の廃置分合等の一覧 (1970-04-01 以降)。
   手元でだけ取り込む (load_local.py municipality_history)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('municipality_history_event') %}
SELECT
    pattern,
    area_code,
    pref_name,
    parent_name,
    name,
    effective_date,
    reason
FROM {{ source('estat_source', 'municipality_history_event') }}
{% else %}
SELECT
    NULL::VARCHAR AS pattern, NULL::VARCHAR AS area_code, NULL::VARCHAR AS pref_name,
    NULL::VARCHAR AS parent_name, NULL::VARCHAR AS name, NULL::VARCHAR AS effective_date, NULL::VARCHAR AS reason
WHERE FALSE
{% endif %}
