{# 令和2年国勢調査 250mメッシュ「人口及び世帯」。
   全国で約5,800万行あり、census の raw は table で実体化する既定のままだと毎日の CI で
   全行を複製することになるので、view にする。
   ロードは手元でだけ行う (load_local_mesh.py)。source がまだ無いカタログでは 0 行の view にする。
   分類は cat01=年齢別人口・世帯の種類別世帯数等、cat02=秘匿・合算区分、area=メッシュコード(10桁)。 #}
{{ config(materialized='view') }}
{% if local_mesh_source_loaded('mesh_population_250m') %}
SELECT
    cat01, cat02, area, unit, value,
    cat01_metadata, cat02_metadata
FROM {{ source('estat_source', 'mesh_population_250m') }}
{% else %}
SELECT
    NULL::VARCHAR AS cat01, NULL::VARCHAR AS cat02, NULL::VARCHAR AS area, NULL::VARCHAR AS unit,
    NULL::DOUBLE AS value, NULL::JSON AS cat01_metadata, NULL::JSON AS cat02_metadata
WHERE FALSE
{% endif %}
