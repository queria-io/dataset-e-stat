{# 商圏分析 (queria.io の /gis と、ページの gis ブロック) が町丁目ごとに引く国勢調査の値を、
   小地域の 5 つの表から 1 本に積んだもの。分析が使う cat01 の行だけを、元の表の行のまま持つ。
   ブラウザの DuckDB は表ごとに大きさの確認・メタデータ・列の中身を 1 往復ずつ順に読むので、
   5 つの表を開くと 50 往復を超える。1 本にまとめると、開くのは 1 回で済む。
   area 順に並べ、行グループの統計で町丁目数十件に絞れるようにする。
   引く cat01 は queria-web の src/lib/gis/sql.ts と揃える。 #}
{% set parts = {
    'census_small_area_age': ['0010', '0170', '0180', '0190',
        '0220', '0230', '0240', '0250', '0260', '0270', '0280', '0290',
        '0300', '0310', '0320', '0330', '0340', '0350', '0360', '0400',
        '0420', '0430', '0440', '0450', '0460', '0470', '0480', '0490',
        '0500', '0510', '0520', '0530', '0540', '0550', '0560', '0600'],
    'census_small_area_household': ['0010', '0030', '0040', '0050'],
    'census_small_area_household_size': ['0010', '0020', '0070'],
    'census_small_area_housing': ['0010', '0020', '0030'],
    'census_small_area_building_type': ['0010', '0020', '0050', '0060', '0070', '0080'],
} %}
{% for source, codes in parts.items() %}
SELECT
    area,
    '{{ source }}' AS source,
    cat01,
    cat02,
    value
FROM {{ ref('stg_' ~ source) }}
WHERE cat01 IN ({% for code in codes %}'{{ code }}'{{ ", " if not loop.last }}{% endfor %})
{{ "UNION ALL" if not loop.last }}
{% endfor %}
ORDER BY area, source, cat01, cat02
