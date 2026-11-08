SELECT
    scope,
    scope_name,
    item_code,
    item,
    unit,
    industry_code,
    industry_name,
    size_code,
    size_name,
    time,
    time_name,
    fiscal_year,
    value
FROM {{ ref('stg_corporate_finance_annual') }}
