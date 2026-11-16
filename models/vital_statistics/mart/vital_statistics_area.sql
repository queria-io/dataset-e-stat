{# 人口動態統計の4表に出る地域に標準地域コードを付ける。
   政令指定都市の合計行は独自のコードなので、今の政令指定都市の名前に当てて標準地域コードに直す。
   ほかの地域は原典のコードのまま。 #}
{{ config(materialized='ephemeral') }}

WITH designated_city AS (
    SELECT pref_code, name AS designated_city_name, area_code
    FROM {{ ref('current_area') }}
    WHERE area_kind = 'designated_city'
)

SELECT
    a.area,
    CASE
        WHEN a.area_kind = 'designated_city' THEN d.area_code
        ELSE a.area
    END AS area_code,
    a.area_name,
    a.area_kind,
    a.prefecture_code
FROM {{ ref('stg_vital_statistics_area') }} AS a
LEFT JOIN designated_city AS d
    ON a.area_kind = 'designated_city'
    AND d.pref_code = a.prefecture_code
    AND d.designated_city_name = a.area_name
