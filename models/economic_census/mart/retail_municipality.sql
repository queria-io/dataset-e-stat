{# 表章項目 (tab) は4項目で固定なので、地域 × 産業の1行に開く (establishment_industry と同じ)。

   事業所数と従業者数の NULL は 0 にする。この2項目は原典に「x」(秘匿) が無く、NULL は
   すべて「-」(該当数字なし) で、0 として足すと都道府県・全国の値に一致する。
   年間商品販売額と売場面積は「x」(秘匿) と「-」がどちらも NULL で来る。事業所が無い
   行は「-」なので 0 にし、事業所がある行の NULL は残す。第2表の町村には、事業所が
   あるのに年間商品販売額が「-」の行がある (小売業計で14町村) ので、0 とは読まない。
   無店舗小売業 (61) は売場を持たないので、売場面積は常に NULL。 #}
WITH wide AS (
    SELECT
        area,
        ANY_VALUE(area_name) AS area_name,
        ANY_VALUE(area_level) AS area_level,
        ANY_VALUE(parent_area) AS parent_area,
        industry_code,
        ANY_VALUE(industry_name) AS industry_name,
        ANY_VALUE(industry_level) AS industry_level,
        ANY_VALUE(parent_industry) AS parent_industry,
        CAST(COALESCE(MAX(value) FILTER (WHERE tab = '701-2021'), 0) AS BIGINT) AS establishments,
        CAST(COALESCE(MAX(value) FILTER (WHERE tab = '723-2021'), 0) AS BIGINT) AS employees,
        CAST(MAX(value) FILTER (WHERE tab = '703-2021') AS BIGINT) AS sales_million_yen,
        CAST(MAX(value) FILTER (WHERE tab = '704-2021') AS BIGINT) AS floor_area_m2
    FROM {{ ref('stg_economic_census_retail') }}
    GROUP BY area, industry_code
)

SELECT
    * REPLACE (
        CASE WHEN establishments = 0 THEN 0 ELSE sales_million_yen END AS sales_million_yen,
        CASE
            WHEN industry_code = '61' THEN NULL
            WHEN establishments = 0 THEN 0
            ELSE floor_area_m2
        END AS floor_area_m2
    )
FROM wide
