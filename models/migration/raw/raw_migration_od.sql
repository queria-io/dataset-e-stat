{# 住民基本台帳人口移動報告の参考表 (load_local.py の migration_od) を縦に積む。
   年と表の種類 (転出先別 outflow / 転入元別 inflow) は統計表そのものが表すので、
   元表の名前から付ける。前住地と現住地のどちらが cat01 に入るかは表で違うので、
   migration_od_sources に表ごとに書いた向きで origin / destination に読み替える。
   国籍の軸 (cat04) は 2020 年以降の表にしかないので、ここでは持たない
   (2017 年以前は日本人移動者、2018 年以降は外国人を含む移動者で、表ごとに 1 区分)。
   元表が揃っていないカタログ (手元で取り込む前) では 0 行にする。
   全 28 表で 1 億 4 千万行あるので、migration の raw の既定 (table) にせず view にする。
   毎日の CI で全行を複製しないため (census の 250m メッシュと同じ)。 #}
{{ config(materialized='view') }}
{% if migration_od_sources_loaded() %}
{% for year, kind, name, origin_in_cat01 in migration_od_sources() %}
{% set origin = 'cat01' if origin_in_cat01 else 'area' %}
{% set destination = 'area' if origin_in_cat01 else 'cat01' %}
SELECT
    {{ year }} AS year,
    '{{ kind }}' AS table_kind,
    {{ origin }} AS origin_code,
    {{ origin }}_metadata->>'$.name' AS origin_name,
    {{ origin }}_metadata->>'$.level' AS origin_meta_level,
    {{ origin }}_metadata->>'$.parent_code' AS origin_meta_parent,
    {{ destination }} AS destination_code,
    {{ destination }}_metadata->>'$.name' AS destination_name,
    {{ destination }}_metadata->>'$.level' AS destination_meta_level,
    {{ destination }}_metadata->>'$.parent_code' AS destination_meta_parent,
    cat02 AS age_code,
    cat02_metadata->>'$.name' AS age,
    cat03 AS sex_code,
    cat03_metadata->>'$.name' AS sex,
    value
FROM {{ source('estat_source', name) }}
{{ 'UNION ALL' if not loop.last }}
{% endfor %}
{% else %}
SELECT
    NULL::INTEGER AS year, NULL::VARCHAR AS table_kind,
    NULL::VARCHAR AS origin_code, NULL::VARCHAR AS origin_name,
    NULL::VARCHAR AS origin_meta_level, NULL::VARCHAR AS origin_meta_parent,
    NULL::VARCHAR AS destination_code, NULL::VARCHAR AS destination_name,
    NULL::VARCHAR AS destination_meta_level, NULL::VARCHAR AS destination_meta_parent,
    NULL::VARCHAR AS age_code, NULL::VARCHAR AS age,
    NULL::VARCHAR AS sex_code, NULL::VARCHAR AS sex,
    NULL::DOUBLE AS value
WHERE FALSE
{% endif %}
