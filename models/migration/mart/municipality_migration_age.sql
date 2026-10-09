{# municipality_migration と同じく、表章項目（転入・転出・転入超過）を横持ちに開く。
   キーに年齢5歳階級が加わる。 #}
SELECT
    area,
    area_name,
    area_level,
    parent_area,
    year,
    sex_code,
    sex,
    nationality_code,
    nationality,
    age_code,
    age,
    MAX(value) FILTER (WHERE measure = 'inflow') AS inflow,
    MAX(value) FILTER (WHERE measure = 'outflow') AS outflow,
    MAX(value) FILTER (WHERE measure = 'net_inflow') AS net_inflow
FROM {{ ref('stg_migration_municipality_age') }}
GROUP BY area, area_name, area_level, parent_area, year,
    sex_code, sex, nationality_code, nationality, age_code, age
