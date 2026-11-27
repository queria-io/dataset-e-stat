{# 人口推計 各年10月1日現在人口 (令和2年国勢調査基準) 都道府県，男女別人口 (0003448232)。
   tab=表章項目 (人口 001 だけ)、cat01=男女別、cat02=総人口・日本人人口。 #}
SELECT
    tab, cat01, cat02, area, time, unit, value,
    cat01_metadata, cat02_metadata, area_metadata, time_metadata
FROM {{ source('estat_source', 'population_estimates_prefecture') }}
