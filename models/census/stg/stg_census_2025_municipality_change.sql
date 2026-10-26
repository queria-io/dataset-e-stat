{# 令和7年国勢調査 人口等基本集計「2020年の人口・世帯数(組替)、5年間の増減、人口性比、
   面積、人口密度」(統計表 0004065882)。2020年の stg_census_municipality_change と同じ形で、
   比べる相手が 2015年から 2020年に替わる。項目ごとに単位が違うので mart で列に開く。 #}
SELECT
    area,
    tab,
    tab_metadata->>'$.name' AS item_name,
    unit,
    TRY_CAST(value AS DOUBLE) AS value
FROM {{ ref('raw_census_2025_municipality_change') }}
