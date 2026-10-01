{# 令和2年国勢調査 小地域(町丁・字等)の住宅の建て方別世帯数。
   表章(tab)・時間軸(time)を持たず、分類は cat01=住宅の建て方、cat02=秘匿・合算区分。
   area は境界データ small_area の key_code と同一体系で、key_code = area で結合できる。 #}
SELECT
    cat01,
    cat01_metadata->>'$.name' AS building_type,
    cat02,
    cat02_metadata->>'$.name' AS secrecy,
    area,
    area_metadata->>'$.name' AS area_name,
    unit,
    TRY_CAST(value AS DOUBLE) AS value
FROM {{ ref('raw_census_small_area_building_type') }}
