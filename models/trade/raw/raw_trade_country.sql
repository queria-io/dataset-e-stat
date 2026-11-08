{# 国名コードと国名。CSV には国名が無いので、データベースの品別国別表の地域軸から取った。
   手元でだけ取り込む (load_local.py trade)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('trade_country') %}
SELECT country_code, country_name
FROM {{ source('estat_source', 'trade_country') }}
{% else %}
SELECT NULL::VARCHAR AS country_code, NULL::VARCHAR AS country_name
WHERE FALSE
{% endif %}
