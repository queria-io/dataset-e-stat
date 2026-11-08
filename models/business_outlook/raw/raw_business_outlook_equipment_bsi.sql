{# 法人企業景気予測調査（統計表 0003326002）。
   手元でだけ取り込む (load_local.py business_outlook)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('business_outlook_equipment_bsi') %}
SELECT
    tab, cat01, cat02, cat03, time, unit, value,
    tab_metadata, cat01_metadata, cat02_metadata, cat03_metadata, time_metadata
FROM {{ source('estat_source', 'business_outlook_equipment_bsi') }}
{% else %}
SELECT
    NULL::VARCHAR AS tab, NULL::VARCHAR AS cat01, NULL::VARCHAR AS cat02, NULL::VARCHAR AS cat03, NULL::VARCHAR AS time, NULL::VARCHAR AS unit, NULL::DOUBLE AS value,
    NULL::JSON AS tab_metadata, NULL::JSON AS cat01_metadata, NULL::JSON AS cat02_metadata, NULL::JSON AS cat03_metadata, NULL::JSON AS time_metadata
WHERE FALSE
{% endif %}
