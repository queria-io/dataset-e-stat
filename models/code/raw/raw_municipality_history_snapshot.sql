{# e-Stat「市区町村を探す」の市区町村コードの一覧を、1970-04-01 と廃置分合等の施行日ごとに取ったもの。
   as_of の日に有効だったコードと名前が並ぶ。
   手元でだけ取り込む (load_local.py municipality_history)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('municipality_history_snapshot') %}
SELECT
    CAST(as_of AS DATE) AS as_of,
    area_code,
    city_type,
    CAST(abolished_date AS DATE) AS abolished_date,
    pref_name,
    parent_name,
    parent_kana,
    name,
    kana
FROM {{ source('estat_source', 'municipality_history_snapshot') }}
{% else %}
SELECT
    NULL::DATE AS as_of, NULL::VARCHAR AS area_code, NULL::VARCHAR AS city_type, NULL::DATE AS abolished_date,
    NULL::VARCHAR AS pref_name, NULL::VARCHAR AS parent_name, NULL::VARCHAR AS parent_kana,
    NULL::VARCHAR AS name, NULL::VARCHAR AS kana
WHERE FALSE
{% endif %}
