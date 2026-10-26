{# 令和3年経済センサス‐活動調査 卸売業，小売業に関する集計 産業編（市区町村表）の
   第1表 (統計表 0004003263) と第2表 (0004003264) から、小売業の行を地域 × 産業中分類 ×
   表章項目の縦持ちで1本にする。

   市区町村表は地域で2つに分かれている。第1表は市・特別区部・特別区・政令指定都市の区
   (と市部計・郡部計) を持ち、町村ごとの行が無い。第2表は町村 (と市部計・郡部計・一部の
   政令指定都市) を持つ。市と区は第1表、町村は第2表 (親が郡部計・振興局計 xx29A の行) から
   取る。全国・都道府県と両表に出る政令指定都市は、両表で値が一致する。
   産業は第2表の粒度にそろえ、小売業計 (I2) と中分類6区分 (56〜61) だけを残す。
   第1表にある小分類は町村に無いので落とす。卸売業の行も落とす。

   市部計・郡部計 (コードに A を含む) は標準地域コードでないので落とす。
   地域軸の level は表で振り方が違う (第1表: 1 全国・都道府県 / 2 市部計・郡部計 /
   3 市・特別区部 / 4 区、第2表: 3 が町村) ので、area_level はコードと親で決める。
   区の親は政令指定都市か特別区部 (13100)。市・町村の親はメタ情報では市部計・郡部計なので、
   都道府県に付け替える。

   表章項目 (tab) は 701 事業所数・723 従業者数・703 年間商品販売額・704 売場面積。
   value は原典の「-」(該当数字なし) と「x」(秘匿) がどちらも NULL で入る。 #}
WITH unioned AS (
    SELECT 'city' AS source_table, * FROM {{ ref('raw_economic_census_retail_city') }}
    UNION ALL BY NAME
    SELECT 'town' AS source_table, * FROM {{ ref('raw_economic_census_retail_town') }}
),

selected AS (
    SELECT *
    FROM unioned
    WHERE regexp_full_match(area, '[0-9]{5}')
        AND cat01 IN ('I2', '56', '57', '58', '59', '60', '61')
        AND (
            source_table = 'city'
            OR (source_table = 'town' AND (area_metadata->>'$.parent_code') LIKE '__29A')
        )
)

SELECT
    area,
    area_metadata->>'$.name' AS area_name,
    CASE
        WHEN area = '00000' THEN 'national'
        WHEN area LIKE '%000' THEN 'prefecture'
        WHEN source_table = 'city' AND (area_metadata->>'$.level') = '4' THEN 'ward'
        ELSE 'municipality'
    END AS area_level,
    CASE
        WHEN area = '00000' THEN NULL
        WHEN area LIKE '%000' THEN '00000'
        WHEN source_table = 'city' AND (area_metadata->>'$.level') = '4'
            THEN area_metadata->>'$.parent_code'
        ELSE SUBSTR(area, 1, 2) || '000'
    END AS parent_area,
    cat01 AS industry_code,
    cat01_metadata->>'$.name' AS industry_name,
    CASE WHEN cat01 = 'I2' THEN 1 ELSE 2 END AS industry_level,
    CASE WHEN cat01 = 'I2' THEN NULL ELSE 'I2' END AS parent_industry,
    tab,
    value
FROM selected
