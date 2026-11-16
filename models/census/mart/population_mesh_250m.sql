{# 令和2年国勢調査 250mメッシュ別の人口・世帯 (縦持ち)。
   view にしているのは、全国で約5,800万行を毎日の CI で複製しないため。 #}
{{ config(materialized='view') }}
SELECT * FROM {{ ref('stg_mesh_population_250m') }}
