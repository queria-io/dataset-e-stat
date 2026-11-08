{# 経済構造実態調査 企業等に関する集計1 を調査年ごとの表から積み、表章項目を名前のそろった
   measure_code に置き換える。表章項目のコードは年で違う（年間商品販売額は2020年までが 021、
   2022年からが 022）。支払利息等（034）は2020年まで、商品売上原価（035）は2022年からしか無い。

   マッピングに無い表章項目が来たら measure_code が NULL になる。
   economic_structure_is_consistent で落とす。 #}
WITH unioned AS (
SELECT
    2019 AS year,
    {{ e_stat_economic_structure_industry_code(2019, 'cat01', "cat01_metadata->>'$.name'") }} AS industry_code,
    {{ e_stat_economic_structure_industry_name(2019, "cat01_metadata->>'$.name'") }} AS industry_name,
    cat02 AS organization_code,
    cat02_metadata->>'$.name' AS organization,
    tab,
    tab_metadata->>'$.name' AS tab_name,
    tab_metadata->>'$.unit' AS unit,
    value
FROM {{ ref('raw_economic_structure_enterprise_2019') }}

UNION ALL

SELECT
    2020 AS year,
    {{ e_stat_economic_structure_industry_code(2020, 'cat01', "cat01_metadata->>'$.name'") }} AS industry_code,
    {{ e_stat_economic_structure_industry_name(2020, "cat01_metadata->>'$.name'") }} AS industry_name,
    cat02 AS organization_code,
    cat02_metadata->>'$.name' AS organization,
    tab,
    tab_metadata->>'$.name' AS tab_name,
    tab_metadata->>'$.unit' AS unit,
    value
FROM {{ ref('raw_economic_structure_enterprise_2020') }}

UNION ALL

SELECT
    2022 AS year,
    {{ e_stat_economic_structure_industry_code(2022, 'cat01', "cat01_metadata->>'$.name'") }} AS industry_code,
    {{ e_stat_economic_structure_industry_name(2022, "cat01_metadata->>'$.name'") }} AS industry_name,
    cat02 AS organization_code,
    cat02_metadata->>'$.name' AS organization,
    tab,
    tab_metadata->>'$.name' AS tab_name,
    tab_metadata->>'$.unit' AS unit,
    value
FROM {{ ref('raw_economic_structure_enterprise_2022') }}

UNION ALL

SELECT
    2023 AS year,
    {{ e_stat_economic_structure_industry_code(2023, 'cat01', "cat01_metadata->>'$.name'") }} AS industry_code,
    {{ e_stat_economic_structure_industry_name(2023, "cat01_metadata->>'$.name'") }} AS industry_name,
    cat02 AS organization_code,
    cat02_metadata->>'$.name' AS organization,
    tab,
    tab_metadata->>'$.name' AS tab_name,
    tab_metadata->>'$.unit' AS unit,
    value
FROM {{ ref('raw_economic_structure_enterprise_2023') }}

UNION ALL

SELECT
    2024 AS year,
    {{ e_stat_economic_structure_industry_code(2024, 'cat01', "cat01_metadata->>'$.name'") }} AS industry_code,
    {{ e_stat_economic_structure_industry_name(2024, "cat01_metadata->>'$.name'") }} AS industry_name,
    cat02 AS organization_code,
    cat02_metadata->>'$.name' AS organization,
    tab,
    tab_metadata->>'$.name' AS tab_name,
    tab_metadata->>'$.unit' AS unit,
    value
FROM {{ ref('raw_economic_structure_enterprise_2024') }}

UNION ALL

SELECT
    2025 AS year,
    {{ e_stat_economic_structure_industry_code(2025, 'cat01', "cat01_metadata->>'$.name'") }} AS industry_code,
    {{ e_stat_economic_structure_industry_name(2025, "cat01_metadata->>'$.name'") }} AS industry_name,
    cat02 AS organization_code,
    cat02_metadata->>'$.name' AS organization,
    tab,
    tab_metadata->>'$.name' AS tab_name,
    tab_metadata->>'$.unit' AS unit,
    value
FROM {{ ref('raw_economic_structure_enterprise_2025') }}
)

SELECT
    year,
    industry_code,
    industry_name,
    {{ e_stat_economic_structure_industry_level('industry_code') }} AS industry_level,
    organization_code,
    organization,
    CASE
        WHEN tab = '01' THEN 'enterprises'
        WHEN tab = '02' THEN 'sales'
        WHEN tab IN ('021', '022') THEN 'merchandise_sales'
        WHEN tab IN ('0211', '0221') THEN 'wholesale_sales'
        WHEN tab IN ('0212', '0222') THEN 'retail_sales'
        WHEN tab = '03' THEN 'total_expenses'
        WHEN tab = '031' THEN 'payroll'
        WHEN tab = '032' THEN 'taxes_and_dues'
        WHEN tab = '034' THEN 'interest_expenses'
        WHEN tab = '035' THEN 'cost_of_goods_sold'
        WHEN tab = '04' THEN 'value_added'
    END AS measure_code,
    replace(replace(tab_name, '（売上（収入）金額）', ''), '（主な費用項目）', '') AS measure,
    COALESCE(unit, CASE WHEN tab = '01' THEN '企業等' END) AS unit,
    value
FROM unioned
