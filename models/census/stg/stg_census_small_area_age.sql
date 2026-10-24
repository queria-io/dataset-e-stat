{# 令和2年国勢調査 小地域(町丁・字等)の年齢別人口。
   表章(tab)・時間軸(time)を持たず、分類は cat01=男女・年齢(総数/男/女 × 5歳階級・4区分)、
   cat02=秘匿・合算区分。男女は cat01 側に入っており cat02 ではない。
   列名 sex は cat02 を指しているが中身は秘匿・合算区分で、公開済みのため名前は変えていない。
   area は境界データ small_area の key_code と同一体系で、key_code = area で結合できる。
   area 順に並べて書き出す。商圏分析は町丁目数十件だけを area で引くので、並んでいれば
   Parquet の行グループ統計で数ブロックに絞れる。並んでいないと 3,000 万行の area 列を
   読み切ることになり、ブラウザの初回で 30 秒前後かかる。 #}
SELECT
    cat01,
    cat01_metadata->>'$.name' AS age_class,
    cat02,
    cat02_metadata->>'$.name' AS sex,
    area,
    area_metadata->>'$.name' AS area_name,
    unit,
    TRY_CAST(value AS DOUBLE) AS value
FROM {{ ref('raw_census_small_area_age') }}
ORDER BY area, cat01, cat02
