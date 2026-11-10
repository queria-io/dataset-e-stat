{# 参考表のうち転入元別の表 (現住地ごとに転入元を並べる)。キーは年・前住地・現住地・性別・年齢。 #}
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
