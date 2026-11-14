{# 参考表のうち転入元別の表 (現住地ごとに転入元を並べる)。キーは年・前住地・現住地・性別・年齢。 #}
{# 約7,200万行あるので、mart の既定 (table) にせず view にする。毎日の CI で全行を複製しないため。 #}
{{ config(materialized='view') }}
SELECT
    year,
    origin_code,
    origin_name,
    origin_level,
    origin_parent,
    destination_code,
    destination_name,
    destination_level,
    destination_parent,
    sex_code,
    sex,
    age_code,
    age,
    nationality_code,
    nationality,
    movers
FROM {{ ref('stg_migration_od') }}
WHERE table_kind = 'inflow'
