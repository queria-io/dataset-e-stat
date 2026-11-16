{# 令和2年国勢調査 1kmメッシュ別の人口・世帯 (縦持ち)。
   昼間人口の推計 (daytime_population_mesh_1km) が按分のウェイトに使っている夜間人口の元の表。 #}
SELECT * FROM {{ ref('stg_mesh_population') }}
