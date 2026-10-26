{# CPI は tab に「指数」「前月比・前年比・前年度比」「前年同月比」の 3 表章があり、
   いずれも分析上重要なため tab_name を保持する（汎用 e_stat_stg_transform は tab_name を落とす）。
   year は time_metadata の名称から西暦4桁を抽出している。

   テーブルにして tab・area・time・cat01 の順に並べる。読み手 (ブラウザの DuckDB) は
   price_index を引くたびに、ビューのままだと _source.cpi (1350 万行・37MB) を頭から
   最後まで読んでいた。行が並んでいないので行グループの統計で読み飛ばせず、名前は JSON から
   取り出すので条件がファイルの読みまで届かない。並べて名前を列に持てば、
   tab_name = '指数' AND area_name = '全国' のような条件でも読む行グループが数個に絞れる。
   追記で増えた _source.cpi の小さいファイルも、ここで 1 つにまとまる。 #}
SELECT
    tab,
    tab_metadata->>'$.name' AS tab_name,
    cat01,
    cat01_metadata->>'$.name' AS item_name,
    area,
    area_metadata->>'$.name' AS area_name,
    time,
    time_metadata->>'$.name' AS time_name,
    TRY_CAST(regexp_extract(time_metadata->>'$.name', '(\d{4})', 1) AS INTEGER) AS year,
    unit,
    TRY_CAST(value AS DOUBLE) AS value
FROM {{ ref('raw_cpi') }}
ORDER BY tab, area, time, cat01
