{# 人口動態統計 確定数 中巻「人口動態総覧（件数），都道府県・市部－郡部－保健所－市区町村別」
   (統計表 0003411564)。cat01=人口動態総覧の12項目、area=都道府県・市部郡部・市区町村、
   time=2015〜2024年。原典の「-」(計数のない場合) は value が NULL で入る。
   手元でだけ取り込む (load_local.py vital_statistics)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('vital_statistics_summary') %}
SELECT
    cat01, area, time, value,
    cat01_metadata, area_metadata
FROM {{ source('estat_source', 'vital_statistics_summary') }}
{% else %}
SELECT
    NULL::VARCHAR AS cat01, NULL::VARCHAR AS area, NULL::VARCHAR AS time, NULL::DOUBLE AS value, NULL::JSON AS cat01_metadata, NULL::JSON AS area_metadata
WHERE FALSE
{% endif %}
