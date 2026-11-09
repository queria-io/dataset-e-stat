{# 参考表のうち転出先別の表 (前住地ごとに転出先を並べる)。キーは年・前住地・現住地・性別・年齢。 #}
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
WHERE table_kind = 'outflow'
