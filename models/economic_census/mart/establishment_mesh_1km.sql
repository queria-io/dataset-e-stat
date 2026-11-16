{# 平成28年経済センサス‐活動調査 1kmメッシュ別の産業大分類別 事業所数・従業者数 (縦持ち)。
   昼間人口の推計 (census.daytime_population_mesh_1km) が流入側のウェイトに使っている従業者数の元の表。
   事業所の所在地で数えるので、従業地ベースの分布になる。 #}
SELECT * FROM {{ ref('stg_mesh_establishment') }}
