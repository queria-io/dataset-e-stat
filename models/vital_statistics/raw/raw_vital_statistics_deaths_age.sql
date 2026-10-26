{# 人口動態統計 確定数 保管統計表 都道府県編「死亡数，都道府県・保健所－市区町村・性・年齢（５歳階級）別・市区町村別」
   (統計表 0003412064)。cat01=年齢、cat02=性別。原典の「-」は value が NULL で入る。
   手元でだけ取り込む (load_local.py vital_statistics)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('vital_statistics_deaths_age') %}
SELECT
    cat01, cat02, area, time, value,
    cat01_metadata, cat02_metadata, area_metadata
FROM {{ source('estat_source', 'vital_statistics_deaths_age') }}
{% else %}
SELECT
    NULL::VARCHAR AS cat01, NULL::VARCHAR AS cat02, NULL::VARCHAR AS area, NULL::VARCHAR AS time, NULL::DOUBLE AS value, NULL::JSON AS cat01_metadata, NULL::JSON AS cat02_metadata, NULL::JSON AS area_metadata
WHERE FALSE
{% endif %}
