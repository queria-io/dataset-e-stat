-- 市区町村・都道府県別の集計で area_level が全行に付いていることを検証する。
-- 結果が0行ならテスト成功。行が返る場合、e-Stat が想定外の level を配り始めている。
--
-- 小地域の area_level が桁数から導けるのに対し、市区町村・都道府県の area は
-- 全て5桁で、粒度は e-Stat のメタ情報が持つ level(1/2/4/5/6/7)にしか無い。
-- 新しい level が増えると CASE がどれにも当たらず NULL が混ざるが、行数も値も
-- 変わらないので黙って通ってしまう。ここで落とす。

{% set municipality_marts = [
    'census_municipality',
    'census_municipality_labor_force',
    'census_municipality_employment_status',
    'census_municipality_daytime_population',
    'census_commuting_flow'
] %}

{% for mart in municipality_marts %}
SELECT '{{ mart }}' AS model_name, area, area_name, area_level
FROM {{ ref(mart) }}
WHERE area_level IS NULL
{% if not loop.last %}UNION ALL{% endif %}
{% endfor %}
