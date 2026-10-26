{# 令和7年国勢調査 人口等基本集計「男女、年齢(5歳階級)、国籍総数か日本人別人口」
   (統計表 0004065920)。cat01=国籍(0 国籍総数 / 1 うち日本人)、cat02=男女(0/1/2)、
   cat03=年齢(00 総数、01〜21 の5歳階級、22 年齢不詳、R1〜R6 の再掲)。
   総数と再掲は mart で落とす。年齢の上下限は区分名から取る。 #}
SELECT
    area,
    area_metadata->>'$.name' AS area_name,
    {{ e_stat_municipality_area_level('area_metadata') }} AS area_level,
    area_metadata->>'$.parent_code' AS parent_area,
    cat01 AS nationality_code,
    cat02 AS sex_code,
    cat03 AS age_code,
    cat03_metadata->>'$.name' AS age_class,
    TRY_CAST(value AS BIGINT) AS value
FROM {{ ref('raw_census_2025_municipality_age') }}
