-- 地方財政状況調査 表0「表紙」(local_finance パイプライン生成の NDJSON)。
-- 市区町村の行だけを持つ。金額は千円、財政力指数は 100 倍した整数。
SELECT
    fiscal_year,
    entity_category_code,
    lg_code,
    pref_name,
    entity_name,
    standard_revenue,
    standard_demand,
    standard_tax_revenue,
    standard_fiscal_scale,
    extraordinary_bond_limit,
    fiscal_capacity_index_x100
FROM read_json(
    'data/local_finance/fiscal_capacity.ndjson',
    columns = {
        fiscal_year: 'INTEGER',
        entity_category_code: 'VARCHAR',
        lg_code: 'VARCHAR',
        pref_name: 'VARCHAR',
        entity_name: 'VARCHAR',
        standard_revenue: 'BIGINT',
        standard_demand: 'BIGINT',
        standard_tax_revenue: 'BIGINT',
        standard_fiscal_scale: 'BIGINT',
        extraordinary_bond_limit: 'BIGINT',
        fiscal_capacity_index_x100: 'INTEGER'
    },
    format = 'newline_delimited'
)
