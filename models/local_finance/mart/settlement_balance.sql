-- 都道府県分と市町村分の調査表を縦に積む。どちらの調査表から来た行かは
-- survey_scope、団体そのものの種別は entity_kind で分かれる。
SELECT
    fiscal_year,
    survey_scope,
    entity_kind,
    entity_category_code,
    area_code,
    lg_code,
    pref_name,
    entity_name,
    revenue_total,
    expenditure_total,
    balance,
    carryover_resources,
    real_balance,
    single_year_balance,
    reserve_fund,
    early_redemption,
    reserve_fund_drawdown,
    real_single_year_balance
FROM {{ ref('stg_local_finance_settlement') }}
