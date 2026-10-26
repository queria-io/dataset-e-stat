{# 商圏分析 (queria.io の /gis と、ページの gis ブロック) が町丁目ごとに引く国勢調査の値を、
   小地域の 5 つの表から 1 本に積んだもの。分析が使う cat01 の行だけを、元の表の行のまま持つ。
   ブラウザの DuckDB は表ごとに大きさの確認・メタデータ・列の中身を 1 往復ずつ順に読むので、
   5 つの表を開くと 50 往復を超える。1 本にまとめると、開くのは 1 回で済む。
   area 順に並べ、行グループの統計で町丁目数十件に絞れるようにする。
   引く cat01 は census_trade_area_codes (queria-web の src/lib/gis/sql.ts と揃える)。 #}
{% set parts = census_trade_area_codes() %}
{% for source, codes in parts.items() %}
SELECT
    area,
    '{{ source }}' AS source,
    cat01,
    cat02,
    value
FROM {{ ref('stg_' ~ source) }}
WHERE cat01 IN ('{{ codes | join("', '") }}')
{{ "UNION ALL" if not loop.last }}
{% endfor %}
ORDER BY area, source, cat01, cat02
