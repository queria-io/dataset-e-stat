-- 商圏分析用の表が、census_trade_area_codes のコードごとに、元の表の同じ cat01 の行と
-- 行数と値の合計で一致する。コードに行が 1 つも無い (書き間違えた) ときも落とす
{% set parts = census_trade_area_codes() %}
WITH expected AS (
    SELECT * FROM (VALUES
{%- for source, codes in parts.items() %}
{%- set outer = loop %}
{%- for code in codes %}
        ('{{ source }}', '{{ code }}'){{ "," if not (outer.last and loop.last) }}
{%- endfor %}
{%- endfor %}
    ) t(source, cat01)
),
combined AS (
    SELECT source, cat01, count(*) AS n, sum(value) AS total
    FROM {{ ref('census_small_area_trade_area') }}
    GROUP BY ALL
),
original AS (
{% for source, codes in parts.items() %}
    SELECT '{{ source }}' AS source, cat01, count(*) AS n, sum(value) AS total
    FROM {{ ref(source) }}
    WHERE cat01 IN ('{{ codes | join("', '") }}')
    GROUP BY ALL
    {{ "UNION ALL" if not loop.last }}
{% endfor %}
)
SELECT source, cat01, c.n AS combined_rows, o.n AS original_rows
FROM expected e
FULL JOIN combined c USING (source, cat01)
LEFT JOIN original o USING (source, cat01)
WHERE c.n IS NULL
   OR o.n IS NULL
   OR c.n IS DISTINCT FROM o.n
   OR abs(coalesce(c.total, 0) - coalesce(o.total, 0)) > 1e-6
