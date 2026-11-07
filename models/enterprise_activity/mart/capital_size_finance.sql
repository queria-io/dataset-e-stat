{# 第3-1表（資産・負債）と第4表（損益・費用）は同じ産業 × 資本金規模の並びなので1つに積む。
   企業数・売上高・経常利益は両方の表にあり値も同じなので、第3-1表の行だけを残す。 #}
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
FROM {{ ref('stg_enterprise_activity') }}
WHERE fiscal_year = survey_year - 1
    AND (
        kind = 'capital_balance'
        OR (kind = 'capital_business' AND measure NOT IN ('企業数', '売上高', '経常利益'))
    )
