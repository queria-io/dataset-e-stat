{# 第3-1表（資産・負債）と第4表（損益・費用）は同じ産業 × 資本金規模の並びなので1つに積む。
   企業数・売上高・経常利益は両方の表にある。値は同じだが秘匿の範囲が一部違い、片方だけ値を
   出しているセルがある（2020年調査の売上高・経常利益で各19セルなど）。第3-1表の値を使い、
   第3-1表が NULL のときは第4表の値を使う。 #}
SELECT
    fiscal_year,
    survey_year,
    industry_code,
    industry_name,
    breakdown_code AS capital_size_code,
    breakdown_name AS capital_size_name,
    measure_code,
    measure,
    unit,
    value
FROM (
    SELECT * FROM {{ ref('stg_enterprise_activity') }}
    UNION ALL
    SELECT * FROM {{ ref('stg_enterprise_activity_legacy') }}
)
WHERE fiscal_year = survey_year - 1
    AND kind IN ('capital_balance', 'capital_business')
QUALIFY row_number() OVER (
    PARTITION BY fiscal_year, industry_code, breakdown_code, measure
    ORDER BY value IS NULL, kind
) = 1
