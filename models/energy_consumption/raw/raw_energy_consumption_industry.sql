{# エネルギー消費統計調査 参考1 都道府県別・業種別エネルギー消費量 (熱量単位表、TJ)。
   手元でだけ取り込む (load_local.py energy_consumption)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('energy_consumption_industry') %}
SELECT
    fiscal_year,
    prefecture_name,
    industry_code,
    industry_name,
    parent_industry_code,
    value
FROM {{ source('estat_source', 'energy_consumption_industry') }}
{% else %}
SELECT
    NULL::INTEGER AS fiscal_year, NULL::VARCHAR AS prefecture_name, NULL::VARCHAR AS industry_code,
    NULL::VARCHAR AS industry_name, NULL::VARCHAR AS parent_industry_code, NULL::DOUBLE AS value
WHERE FALSE
{% endif %}
