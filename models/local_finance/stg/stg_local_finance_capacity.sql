-- 財政力指数は元データが小数第2位までを100倍した整数で持つ。ここで戻す。
-- 割り算をパイプライン側でやると、丸めの桁がコードのどこにも残らない。
SELECT
    fiscal_year,
    entity_category_code,
    lg_code,
    LEFT(lg_code, 5) AS area_code,
    pref_name,
    entity_name,
    standard_revenue,
    standard_demand,
    standard_tax_revenue,
    standard_fiscal_scale,
    extraordinary_bond_limit,
    -- DuckDB の割り算は DECIMAL 同士でも DOUBLE を返すので、外側で型を決める。
    CAST(fiscal_capacity_index_x100 / 100.0 AS DECIMAL(5, 2)) AS fiscal_capacity_index
FROM {{ ref('raw_local_finance_capacity') }}
