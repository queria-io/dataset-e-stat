{# 総括表は全産業の過去5年度の値を持つので、同じ年度が複数の調査に出る。年度ごとに、
   いちばん新しい調査の値を使う。 #}
SELECT
    fiscal_year,
    survey_year,
    industry_code,
    industry_name,
    measure_code,
    measure,
    unit,
    value
FROM (
    SELECT * FROM {{ ref('stg_enterprise_activity') }}
    UNION ALL
    SELECT * FROM {{ ref('stg_enterprise_activity_legacy') }}
)
WHERE kind = 'summary'
QUALIFY survey_year = max(survey_year) OVER (PARTITION BY fiscal_year)
