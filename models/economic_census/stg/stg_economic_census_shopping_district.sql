{# 令和3年経済センサス‐活動調査 立地環境特性編 商業集積地区別の表 (統計表 0004015880) を、
   地区・地域の計 × 産業 × 表章項目の縦持ちにする。

   cat01 は8桁で、上5桁が標準地域コード、下3桁が市区町村の中の商業集積地区の番号。
   計の行は下3桁が 000 で、全国計・都道府県計・市区町村計・区計 (メタ情報の level 1〜4)。
   商業集積地区 (level 5) の親は市区町村計か、政令指定都市・特別区部の区計。
   地区名の末尾の【11】〜【15】は立地環境特性の細分類 (統計表 0004015860 の cat01 と同じ
   コード) なので、名前から外して district_type_code に移す。

   表章項目 (tab) のうち 801 商店街数と 802 大規模小売店舗数は計の行にしか無く
   (cat02 = 00)、地区の行は 803 事業所数・804 大規模小売店舗内事業所数・805 従業者数・
   806 売上（収入）金額・807 売場面積 (小売業だけ) を持つ。801・802 は落とす
   (商店街数は地区の行を数えれば出る)。
   value は原典の「-」(該当数字なし) と「x」(秘匿) がどちらも NULL で入る。 #}
WITH src AS (
    SELECT
        cat01,
        cat01_metadata->>'$.name' AS name,
        CAST(cat01_metadata->>'$.level' AS INTEGER) AS meta_level,
        cat01_metadata->>'$.parent_code' AS parent_code,
        cat02,
        cat02_metadata->>'$.name' AS industry_name,
        tab,
        value
    FROM {{ ref('raw_economic_census_shopping_district') }}
    WHERE cat02 IN ('I2', 'M2', 'N')
)

SELECT
    cat01 AS district_code,
    CASE meta_level
        WHEN 5 THEN regexp_replace(name, '【1[1-5]】$', '')
        ELSE name
    END AS district_name,
    CASE meta_level
        WHEN 1 THEN 'national'
        WHEN 2 THEN 'prefecture'
        WHEN 3 THEN 'municipality'
        WHEN 4 THEN 'ward'
        WHEN 5 THEN 'district'
    END AS district_level,
    SUBSTR(cat01, 1, 5) AS area,
    parent_code AS parent_district_code,
    CASE WHEN meta_level = 5 THEN regexp_extract(name, '【(1[1-5])】$', 1) END AS district_type_code,
    cat02 AS industry_code,
    industry_name,
    tab,
    value
FROM src
