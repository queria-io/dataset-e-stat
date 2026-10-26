{# 令和7年国勢調査 人口等基本集計「男女別人口」(統計表 0004065881)。
   2020年の stg_census_municipality_population と同じ形。cat01=男女(総数/男/女)。 #}
SELECT
    area,
    area_metadata->>'$.name' AS area_name,
    {{ e_stat_municipality_area_level('area_metadata') }} AS area_level,
    area_metadata->>'$.parent_code' AS parent_area,
    cat01,
    cat01_metadata->>'$.name' AS sex,
    TRY_CAST(value AS BIGINT) AS value
FROM {{ ref('raw_census_2025_municipality_population') }}
