-- census の area_level が全行に付いていることを検証する。
-- 結果が0行ならテスト成功。行が返る場合、想定していない桁数の area が現れている。
--
-- area_level は area の桁数（5=市区町村 / 9=町丁・字等 / 11=その内訳）から導いている。
-- 上流が別の桁数を配り始めると CASE がどれにも当たらず NULL が混ざるが、行数も値も
-- 変わらないので黙って通ってしまう。ここで落とす。

{% set census_marts = [
    'census_small_area_age',
    'census_small_area_household',
    'census_small_area_industry',
    'census_small_area_housing',
    'census_small_area_household_size',
    'census_small_area_building_type',
    'census_small_area_economic_type'
] %}

{% for mart in census_marts %}
SELECT '{{ mart }}' AS model_name, area, LENGTH(area) AS area_length
FROM {{ ref(mart) }}
WHERE area_level IS NULL
{% if not loop.last %}UNION ALL{% endif %}
{% endfor %}
