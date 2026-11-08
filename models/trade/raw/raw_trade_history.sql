{# 普通貿易統計 品別国別表（全国分）の過去の年（local_tables.yml の trade グループの
   through_year まで）。12月分の CSV を手元で1回だけ取り込み、HS コード順に並べてある。
   手元でだけ取り込む (load_local.py trade)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('trade_history') %}
SELECT flow, year, month, hs_code, country_code, unit1, unit2, quantity1, quantity2, value, release
FROM {{ source('estat_source', 'trade_history') }}
{% else %}
SELECT
    NULL::VARCHAR AS flow, NULL::SMALLINT AS year, NULL::TINYINT AS month, NULL::VARCHAR AS hs_code,
    NULL::VARCHAR AS country_code, NULL::VARCHAR AS unit1, NULL::VARCHAR AS unit2,
    NULL::BIGINT AS quantity1, NULL::BIGINT AS quantity2, NULL::BIGINT AS value, NULL::VARCHAR AS release
WHERE FALSE
{% endif %}
