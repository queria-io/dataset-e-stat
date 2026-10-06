{# 建築着工統計調査の市区町村別・用途別（大分類）を、年代をまたいで1つに積む。

   統計表は2019年までと2020年以降で分かれる。表章コードはどちらも 12=建築物の数・
   13=床面積の合計で、2019年までの表にだけ 14=工事費予定額 がある。用途（cat01）の
   コードと名称は両方で同じ。表章を列に広げ、工事費予定額は2020年以降 NULL になる。

   地域軸には市区町村と政令指定都市の区のほかに、次の集計行が入っている。
     - 郡・北海道の振興局・東京都の支庁（level=3 で下3桁が300以上）: 町村の合計
     - 特別区部（13100）: 特別区の合計
   2020〜2023年の集計行は値が 0 のまま載っていて（実測: 325行中321行）、子の合計と
   一致するのは2024年だけ。年で意味が変わるので集計行は落とす。区は政令指定都市の
   内訳として area_level = 'ward' で残す。特別区は市区町村と同じ階層に置く。

   着工が1棟も無い年の地域は、2019年までと2024年の表には行が無く、2020〜2023年の表
   にだけ全用途 0 の行がある（浜松市の行政区再編前に新しい区の 0 の行が並ぶのもこれ）。
   年で載せ方が揃うように、建築物の数の計が 0 の地域・年は落とす。

   原典の「＊」（秘匿）はローダーが数値に直す時点で NULL になる。工事費予定額は
   用途の内訳の2割ほどが秘匿で、床面積にも1セルある（2018年 新潟市北区 教育，学習
   支援業用）。 #}
WITH combined AS (
    SELECT tab, cat01, cat01_metadata, area, area_metadata, time, value
    FROM {{ ref('raw_building_starts_municipality_use') }}

    UNION ALL

    SELECT tab, cat01, cat01_metadata, area, area_metadata, time, value
    FROM {{ ref('raw_building_starts_municipality_use_pre2020') }}
),

classified AS (
    SELECT
        *,
        CASE
            WHEN area = '13100' THEN 'aggregate'
            WHEN area_metadata->>'$.level' = '3'
                AND TRY_CAST(SUBSTR(area, 3, 3) AS INTEGER) >= 300 THEN 'aggregate'
            WHEN area_metadata->>'$.parent_code' <> '13100'
                AND TRY_CAST(SUBSTR(area_metadata->>'$.parent_code', 3, 3) AS INTEGER)
                    BETWEEN 100 AND 199 THEN 'ward'
            ELSE 'municipality'
        END AS area_level
    FROM combined
),

pivoted AS (
    SELECT
        area,
        ANY_VALUE(area_metadata->>'$.name') AS area_name,
        area_level,
        CASE area_level
            WHEN 'ward' THEN ANY_VALUE(area_metadata->>'$.parent_code')
            ELSE SUBSTR(area, 1, 2) || '000'
        END AS parent_area,
        time,
        cat01 AS use_code,
        ANY_VALUE(cat01_metadata->>'$.name') AS use_name,
        MAX(TRY_CAST(value AS BIGINT)) FILTER (WHERE tab = '12') AS buildings,
        MAX(TRY_CAST(value AS BIGINT)) FILTER (WHERE tab = '13') AS floor_area,
        MAX(TRY_CAST(value AS BIGINT)) FILTER (WHERE tab = '14') AS construction_cost
    FROM classified
    WHERE area_level <> 'aggregate'
    GROUP BY area, area_level, time, cat01
),

started AS (
    SELECT area, time
    FROM pivoted
    WHERE use_code = '11' AND buildings > 0
)

SELECT
    p.area,
    p.area_name,
    p.area_level,
    p.parent_area,
    p.time,
    TRY_CAST(SUBSTR(p.time, 1, 4) AS INTEGER) AS year,
    p.use_code,
    p.use_name,
    p.buildings,
    p.floor_area,
    p.construction_cost
FROM pivoted p
INNER JOIN started s USING (area, time)
