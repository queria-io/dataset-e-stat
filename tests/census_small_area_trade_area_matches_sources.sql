-- 商圏分析用の表が、元の 5 つの表の同じ cat01 の行と、行数と値の合計で一致する
{% set sources = ['census_small_area_age', 'census_small_area_household', 'census_small_area_household_size', 'census_small_area_housing', 'census_small_area_building_type'] %}
WITH combined AS (
    SELECT source, cat01, count(*) AS n, sum(value) AS total
    FROM {{ ref('census_small_area_trade_area') }}
    GROUP BY ALL
),
original AS (
{% for s in sources %}
    SELECT '{{ s }}' AS source, cat01, count(*) AS n, sum(value) AS total
    FROM {{ ref(s) }}
    WHERE cat01 IN (SELECT cat01 FROM combined WHERE source = '{{ s }}')
    GROUP BY ALL
    {{ "UNION ALL" if not loop.last }}
{% endfor %}
)
SELECT *
FROM combined c
FULL JOIN original o USING (source, cat01)
WHERE c.n IS DISTINCT FROM o.n
   OR abs(coalesce(c.total, 0) - coalesce(o.total, 0)) > 1e-6
