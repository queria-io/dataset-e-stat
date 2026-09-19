-- 地方財政状況調査 表2「決算収支の状況」(local_finance パイプライン生成の NDJSON)。
-- 団体コードは先頭ゼロを保つため VARCHAR で読む。金額はすべて千円。
SELECT
    fiscal_year,
    survey_scope,
    entity_kind,
    entity_category_code,
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
FROM read_json(
    'data/local_finance/settlement.ndjson',
    columns = {
        fiscal_year: 'INTEGER',
        survey_scope: 'VARCHAR',
        entity_kind: 'VARCHAR',
        entity_category_code: 'VARCHAR',
        lg_code: 'VARCHAR',
        pref_name: 'VARCHAR',
        entity_name: 'VARCHAR',
        revenue_total: 'BIGINT',
        expenditure_total: 'BIGINT',
        balance: 'BIGINT',
        carryover_resources: 'BIGINT',
        real_balance: 'BIGINT',
        single_year_balance: 'BIGINT',
        reserve_fund: 'BIGINT',
        early_redemption: 'BIGINT',
        reserve_fund_drawdown: 'BIGINT',
        real_single_year_balance: 'BIGINT'
    },
    format = 'newline_delimited'
)
