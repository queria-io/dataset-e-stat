{# 平成28年経済センサス‐活動調査 1kmメッシュ別の事業所数・従業者数。値を数にし、区分に名前を付ける #}
{{ config(materialized='ephemeral') }}

SELECT
    area AS mesh_code,
    SUBSTR(area, 1, 4) AS mesh1_code,
    cat01,
    TRIM(cat01_metadata->>'$.name', '　 ') AS category,
    unit,
    TRY_CAST(value AS DOUBLE) AS value
FROM {{ ref('raw_mesh_establishment') }}
