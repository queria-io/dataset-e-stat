-- 団体コード(6桁・全国地方公共団体コード)から標準地域コード(5桁)を切り出す。
-- 本データセットの census / boundary / code は 5桁側の体系なので、そこで結合する。
-- 「合計(全国)」の行はコードを持たないため NULL のまま残る。
SELECT
    fiscal_year,
    survey_scope,
    entity_kind,
    entity_category_code,
    lg_code,
    LEFT(lg_code, 5) AS area_code,
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
FROM {{ ref('raw_local_finance_settlement') }}
