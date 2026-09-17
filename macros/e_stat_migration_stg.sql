{# 住民基本台帳人口移動報告の市区町村別表を年代をまたいで1つに積む。

   2020年以降は1表に転入・転出・転入超過が同居し（表章コード 21 / 22 / 04）、
   2019年以前は表章ごとに3表へ分かれる（11 / 12 / 04）。表章コードは年代で違うので、
   転入 / 転出 / 転入超過 を表す measure に読み替える。

   分類軸の並びも年代で違う。2020年以降は cat01=年齢・cat02=性別・cat03=国籍、
   2019年以前は cat01=性別・cat02=国籍・cat03=年齢。年齢は取得時に総数（000）へ絞って
   いるが、ここでも絞る。取得の条件が外れて年齢階級が入ってくると、mart の
   地域×年×性別×国籍 が一意でなくなり、どの階級の値が残るかは不定になる。

   表章にはもう1つ、2020年以降の「移動前の住所地不詳」(23) と 2019年以前の「その他」(32)
   がある。どちらも転入者数にも転入超過数にも含まれない別枠の数で、指しているものが
   年代で違う（不詳と、国外からの転入・職権記載等）。同じ列に積むと年で意味が変わる列に
   なるため取らない。必要なら国外からの転入は専用の統計表がある。

   UNION は列を明示して積む。BY NAME に頼ると、片方の表に e-Stat が軸を足したときに
   列が入れ替わったまま通ってしまう。 #}
{% macro e_stat_migration_stg(current_model, inflow_model, outflow_model, net_model) %}
WITH pre2020 AS (
    SELECT tab, cat01, cat01_metadata, cat02, cat02_metadata, cat03,
           area, area_metadata, time, unit, value
    FROM {{ ref(inflow_model) }}

    UNION ALL

    SELECT tab, cat01, cat01_metadata, cat02, cat02_metadata, cat03,
           area, area_metadata, time, unit, value
    FROM {{ ref(outflow_model) }}

    UNION ALL

    SELECT tab, cat01, cat01_metadata, cat02, cat02_metadata, cat03,
           area, area_metadata, time, unit, value
    FROM {{ ref(net_model) }}
),

combined AS (
    SELECT
        CASE tab
            WHEN '21' THEN 'inflow'
            WHEN '22' THEN 'outflow'
            WHEN '04' THEN 'net_inflow'
        END AS measure,
        cat02 AS sex_code,
        cat02_metadata->>'$.name' AS sex,
        cat03 AS nationality_code,
        cat03_metadata->>'$.name' AS nationality,
        area,
        area_metadata->>'$.name' AS area_name,
        {{ e_stat_migration_area_level('area', 'area_metadata') }} AS area_level,
        area_metadata->>'$.parent_code' AS parent_area,
        time,
        unit,
        value
    FROM {{ ref(current_model) }}
    WHERE cat01 = '000'

    UNION ALL

    SELECT
        CASE tab
            WHEN '11' THEN 'inflow'
            WHEN '12' THEN 'outflow'
            WHEN '04' THEN 'net_inflow'
        END AS measure,
        cat01 AS sex_code,
        cat01_metadata->>'$.name' AS sex,
        cat02 AS nationality_code,
        cat02_metadata->>'$.name' AS nationality,
        area,
        area_metadata->>'$.name' AS area_name,
        {{ e_stat_migration_area_level('area', 'area_metadata') }} AS area_level,
        area_metadata->>'$.parent_code' AS parent_area,
        time,
        unit,
        value
    FROM pre2020
    WHERE cat03 = '000'
)

SELECT
    measure,
    sex_code,
    sex,
    nationality_code,
    nationality,
    area,
    area_name,
    area_level,
    parent_area,
    time,
    TRY_CAST(SUBSTR(time, 1, 4) AS INTEGER) AS year,
    unit,
    TRY_CAST(value AS BIGINT) AS value
FROM combined
WHERE measure IS NOT NULL
{% endmacro %}
