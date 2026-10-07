{# 令和2年国勢調査 250mメッシュ別の人口・世帯 (縦持ち)。
   view にしているのは、全国で約5,800万行を毎日の CI で複製しないため。 #}
{{ config(materialized='view') }}
SELECT
    area AS mesh_code,
    SUBSTR(area, 1, 8) AS mesh_1km_code,
    SUBSTR(area, 1, 4) AS mesh1_code,
    cat01,
    TRIM(cat01_metadata->>'$.name', '　 ') AS category,
    cat02,
    cat02_metadata->>'$.name' AS suppression,
    unit,
    TRY_CAST(value AS DOUBLE) AS value
FROM {{ ref('raw_mesh_population_250m') }}
