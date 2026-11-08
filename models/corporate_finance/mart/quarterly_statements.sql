SELECT
    scope,
    scope_name,
    seasonally_adjusted,
    item_code,
    item,
    unit,
    industry_code,
    industry_name,
    size_code,
    size_name,
    time,
    time_name,
    year,
    quarter,
    fiscal_year,
    value
FROM {{ ref('stg_corporate_finance_quarterly') }}
