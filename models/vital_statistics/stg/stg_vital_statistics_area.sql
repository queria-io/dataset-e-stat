{# 人口動態統計の4表に出る地域を、標準地域コードと集計の段にそろえる。

   地域軸は表によって違う。人口動態総覧 (summary) は都道府県の下に「市部」「郡部」
   「その他の市」「都区部」の集計行と、政令指定都市の合計行を持つ。政令指定都市の
   合計行は標準地域コードではなく、都道府県コードの後ろに 010・020… を振った独自の
   コード (札幌市 01010、横浜市 14010、浜松市 22030 など) になっている。ほかの3表は
   集計行も政令指定都市の合計行も持たず、代わりに全国 (00000)・外国 (51000)・
   不詳 (52000) を持つ。

   下3桁が 0 で始まる地域 (XX0X0) は集計行か政令指定都市の合計行で、名前で分ける。
   政令指定都市は code.municipality の合計行に名前で当てて標準地域コードに直す。
   市部・郡部などの集計行は落とす (コードが標準地域コードと紛らわしく、
   市区町村から足し上げられる)。 #}
WITH areas AS (
    {% for t in ['summary', 'births_mother_age', 'deaths_age', 'deaths_cause'] %}
    SELECT DISTINCT
        area,
        area_metadata->>'$.name' AS area_name,
        area_metadata->>'$.level' AS area_meta_level
    FROM {{ ref('raw_vital_statistics_' ~ t) }}
    {{ 'UNION' if not loop.last }}
    {% endfor %}
),

classified AS (
    SELECT
        area,
        area_name,
        CASE
            WHEN area = '00000' THEN 'nationwide'
            WHEN area = '51000' THEN 'foreign'
            WHEN area = '52000' THEN 'unknown'
            WHEN area LIKE '%000' THEN 'prefecture'
            WHEN area_meta_level = '4' THEN 'ward'
            WHEN SUBSTR(area, 3, 1) = '0'
                AND area_name IN ('市部', '郡部', 'その他の市', '都区部') THEN 'urban_rural_part'
            WHEN SUBSTR(area, 3, 1) = '0' THEN 'designated_city'
            ELSE 'municipality'
        END AS area_kind
    FROM areas
),

designated_city AS (
    SELECT pref_code, designated_city_name, area_code
    FROM {{ ref('municipality') }}
    WHERE area_kind = 'designated_city'
)

SELECT
    c.area,
    CASE
        WHEN c.area_kind = 'designated_city' THEN d.area_code
        ELSE c.area
    END AS area_code,
    c.area_name,
    c.area_kind,
    CASE
        WHEN c.area_kind NOT IN ('nationwide', 'foreign', 'unknown') THEN SUBSTR(c.area, 1, 2)
    END AS prefecture_code
FROM classified AS c
LEFT JOIN designated_city AS d
    ON c.area_kind = 'designated_city'
    AND d.pref_code = SUBSTR(c.area, 1, 2)
    AND d.designated_city_name = c.area_name
WHERE c.area_kind <> 'urban_rural_part'
