{# 手元でだけ取り込む (load_local.py census_2025)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('census_2025_municipality_age') %}
SELECT
    cat01, cat02, cat03, area, unit, value,
    cat01_metadata, cat02_metadata, cat03_metadata, area_metadata
FROM {{ source('estat_source', 'census_2025_municipality_age') }}
{% else %}
SELECT
    NULL::VARCHAR AS cat01, NULL::VARCHAR AS cat02, NULL::VARCHAR AS cat03, NULL::VARCHAR AS area,
    NULL::VARCHAR AS unit, NULL::DOUBLE AS value, NULL::JSON AS cat01_metadata, NULL::JSON AS cat02_metadata,
    NULL::JSON AS cat03_metadata, NULL::JSON AS area_metadata
WHERE FALSE
{% endif %}
