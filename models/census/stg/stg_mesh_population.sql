{# 令和2年国勢調査 1kmメッシュ別の人口・世帯。値を数にし、区分に名前を付ける #}
{{ config(materialized='ephemeral') }}

SELECT
    area AS mesh_code,
    SUBSTR(area, 1, 4) AS mesh1_code,
    cat01,
    TRIM(cat01_metadata->>'$.name', '　 ') AS category,
    cat02,
    cat02_metadata->>'$.name' AS suppression,
    unit,
    TRY_CAST(value AS DOUBLE) AS value
FROM {{ ref('raw_mesh_population') }}
