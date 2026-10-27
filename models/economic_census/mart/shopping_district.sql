{# 表章項目 (tab) を開いて、地区 (と地域の計) × 産業の1行にする (retail_municipality と同じ)。

   事業所数・大規模小売店舗内事業所数・従業者数の NULL は 0 にする。この3項目は子の和が
   親の計にちょうど一致し、NULL は「-」(該当数字なし) として足すと合う。
   売上（収入）金額と売場面積は「x」(秘匿) と「-」がどちらも NULL で来る。事業所が無い
   行は「-」なので 0 にし、事業所がある行の NULL は残す。売場面積は事業所があっても「-」の
   地区があり (計から差し引くと 0 になる地区が少なくとも 444)、秘匿と区別できないので NULL のまま。
   売場面積は小売業 (I2) にしか無い。 #}
WITH wide AS (
    SELECT
        district_code,
        ANY_VALUE(district_name) AS district_name,
        ANY_VALUE(district_level) AS district_level,
        ANY_VALUE(area) AS area,
        ANY_VALUE(parent_district_code) AS parent_district_code,
        ANY_VALUE(district_type_code) AS district_type_code,
        industry_code,
        ANY_VALUE(industry_name) AS industry_name,
        CAST(COALESCE(MAX(value) FILTER (WHERE tab = '803-2021'), 0) AS BIGINT) AS establishments,
        CAST(COALESCE(MAX(value) FILTER (WHERE tab = '804-2021'), 0) AS BIGINT)
            AS establishments_in_large_stores,
        CAST(COALESCE(MAX(value) FILTER (WHERE tab = '805-2021'), 0) AS BIGINT) AS employees,
        CAST(MAX(value) FILTER (WHERE tab = '806-2021') AS BIGINT) AS sales_million_yen,
        CAST(MAX(value) FILTER (WHERE tab = '807-2021') AS BIGINT) AS floor_area_m2
    FROM {{ ref('stg_economic_census_shopping_district') }}
    GROUP BY district_code, industry_code
)

SELECT
    district_code,
    district_name,
    district_level,
    area,
    parent_district_code,
    district_type_code,
    CASE district_type_code
        WHEN '11' THEN '駅周辺型商業集積地区'
        WHEN '12' THEN '市街地型商業集積地区'
        WHEN '13' THEN '住宅地背景型商業集積地区'
        WHEN '14' THEN 'ロードサイド型商業集積地区'
        WHEN '15' THEN 'その他の商業集積地区'
    END AS district_type,
    industry_code,
    industry_name,
    establishments,
    establishments_in_large_stores,
    employees,
    CASE WHEN establishments = 0 THEN 0 ELSE sales_million_yen END AS sales_million_yen,
    CASE
        WHEN industry_code <> 'I2' THEN NULL
        WHEN establishments = 0 THEN 0
        ELSE floor_area_m2
    END AS floor_area_m2
FROM wide
