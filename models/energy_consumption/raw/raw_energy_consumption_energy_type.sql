{# エネルギー消費統計調査 参考2 都道府県別・エネルギー種別エネルギー消費量 (熱量単位表、TJ)。
   手元でだけ取り込む (load_local.py energy_consumption)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('energy_consumption_energy_type') %}
SELECT
    fiscal_year,
    prefecture_name,
    energy_type,
    parent_energy_type,
    value
FROM {{ source('estat_source', 'energy_consumption_energy_type') }}
{% else %}
SELECT
    NULL::INTEGER AS fiscal_year, NULL::VARCHAR AS prefecture_name, NULL::VARCHAR AS energy_type,
    NULL::VARCHAR AS parent_energy_type, NULL::DOUBLE AS value
WHERE FALSE
{% endif %}
