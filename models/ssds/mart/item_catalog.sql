{{ config(materialized='table') }}

WITH ssds_tables AS (
    SELECT DISTINCT stats_data_id AS id, table_title AS title
    FROM {{ ref('stats_catalog') }}
    -- 社会・人口統計体系: https://www.e-stat.go.jp/statistics/00200502
    WHERE stat_code = '00200502'
)

SELECT
    s.title AS table_title,
    m.stats_data_id,
    m.class_id,
    m.class_name,
    m.class_description,
    m.item_code,
    m.item_name,
    m.level,
    m.unit,
    m.parent_code,
    m.add_inf
FROM {{ ref('stg_meta_info') }} m
JOIN ssds_tables s ON m.stats_data_id = s.id
WHERE m.class_id NOT IN ('tab', 'area', 'time')
