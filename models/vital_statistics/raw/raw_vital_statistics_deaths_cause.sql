{# 人口動態統計 確定数 保管統計表 都道府県編「死亡数，都道府県・市区町村・死因（選択死因分類）・性別」
   (統計表 0003412081)。cat01=性別、cat02=選択死因分類。原典の「-」(計数のない場合) と
   「・」(統計項目のあり得ない場合) はどちらも value が NULL で入る。
   手元でだけ取り込む (load_local.py vital_statistics)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('vital_statistics_deaths_cause') %}
SELECT
    cat01, cat02, area, time, value,
    cat01_metadata, cat02_metadata, area_metadata
FROM {{ source('estat_source', 'vital_statistics_deaths_cause') }}
{% else %}
SELECT
    NULL::VARCHAR AS cat01, NULL::VARCHAR AS cat02, NULL::VARCHAR AS area, NULL::VARCHAR AS time, NULL::DOUBLE AS value, NULL::JSON AS cat01_metadata, NULL::JSON AS cat02_metadata, NULL::JSON AS area_metadata
WHERE FALSE
{% endif %}
