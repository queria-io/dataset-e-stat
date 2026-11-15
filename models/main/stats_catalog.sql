{{ config(materialized='table') }}

WITH class_deduped AS (
    SELECT stats_data_id, class_name, MIN(class_id) AS class_id
    FROM {{ ref('stg_meta_info') }}
    WHERE class_id NOT IN ('area', 'time')
    GROUP BY stats_data_id, class_name
),

class_names AS (
    SELECT
        stats_data_id,
        LIST(class_name ORDER BY class_id) AS class_names
    FROM class_deduped
    GROUP BY stats_data_id
),

tables AS (
    SELECT DISTINCT
        id, stat_code, stat_name, gov_org_name,
        statistics_name, title,
        main_category_code, main_category,
        sub_category_code, sub_category,
        collect_area, cycle, survey_date, updated_date
    FROM {{ ref('stg_stats_list') }}
)

SELECT
    t.id AS stats_data_id,
    t.stat_code,
    t.stat_name,
    t.gov_org_name,
    t.statistics_name,
    t.title AS table_title,
    t.main_category_code,
    t.main_category,
    t.sub_category_code,
    t.sub_category,
    t.collect_area,
    t.cycle,
    t.survey_date,
    t.updated_date,
    c.class_names
FROM tables t
LEFT JOIN class_names c ON t.id = c.stats_data_id
ORDER BY t.main_category, t.sub_category, t.stat_name, t.id
