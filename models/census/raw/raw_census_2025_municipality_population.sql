{# 手元でだけ取り込む (load_local.py census_2025)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('census_2025_municipality_population') %}
SELECT
    cat01, area, unit, value,
    cat01_metadata, area_metadata
FROM {{ source('estat_source', 'census_2025_municipality_population') }}
{% else %}
SELECT
    NULL::VARCHAR AS cat01, NULL::VARCHAR AS area, NULL::VARCHAR AS unit, NULL::DOUBLE AS value,
    NULL::JSON AS cat01_metadata, NULL::JSON AS area_metadata
WHERE FALSE
{% endif %}
