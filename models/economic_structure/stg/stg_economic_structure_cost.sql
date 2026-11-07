{# 経済構造実態調査 企業等に関する集計2（事業区分別費用内訳割合）を調査年ごとの表から積む。
   費用項目の名称は「（産業共通）_給与総額」「（電気業）_燃料費」のように、どの事業区分の項目かを
   括弧で前置きしている。括弧の中を cost_scope、下線のあとを cost_item に分ける。「その他」だけは
   前置きが無い。費用項目のコードは2024年に一部が「1022-2024」の形に振り直されている。 #}
WITH unioned AS (
SELECT
    2019 AS year,
    {{ e_stat_economic_structure_industry_code(2019, 'cat01', "cat01_metadata->>'$.name'") }} AS business_code,
    {{ e_stat_economic_structure_industry_name(2019, "cat01_metadata->>'$.name'") }} AS business_name,
    tab AS cost_item_code,
    tab_metadata->>'$.name' AS tab_name,
    value
FROM {{ ref('raw_economic_structure_cost_2019') }}

UNION ALL

SELECT
    2020 AS year,
    {{ e_stat_economic_structure_industry_code(2020, 'cat01', "cat01_metadata->>'$.name'") }} AS business_code,
    {{ e_stat_economic_structure_industry_name(2020, "cat01_metadata->>'$.name'") }} AS business_name,
    tab AS cost_item_code,
    tab_metadata->>'$.name' AS tab_name,
    value
FROM {{ ref('raw_economic_structure_cost_2020') }}

UNION ALL

SELECT
    2022 AS year,
    {{ e_stat_economic_structure_industry_code(2022, 'cat01', "cat01_metadata->>'$.name'") }} AS business_code,
    {{ e_stat_economic_structure_industry_name(2022, "cat01_metadata->>'$.name'") }} AS business_name,
    tab AS cost_item_code,
    tab_metadata->>'$.name' AS tab_name,
    value
FROM {{ ref('raw_economic_structure_cost_2022') }}

UNION ALL

SELECT
    2023 AS year,
    {{ e_stat_economic_structure_industry_code(2023, 'cat01', "cat01_metadata->>'$.name'") }} AS business_code,
    {{ e_stat_economic_structure_industry_name(2023, "cat01_metadata->>'$.name'") }} AS business_name,
    tab AS cost_item_code,
    tab_metadata->>'$.name' AS tab_name,
    value
FROM {{ ref('raw_economic_structure_cost_2023') }}

UNION ALL

SELECT
    2024 AS year,
    {{ e_stat_economic_structure_industry_code(2024, 'cat01', "cat01_metadata->>'$.name'") }} AS business_code,
    {{ e_stat_economic_structure_industry_name(2024, "cat01_metadata->>'$.name'") }} AS business_name,
    tab AS cost_item_code,
    tab_metadata->>'$.name' AS tab_name,
    value
FROM {{ ref('raw_economic_structure_cost_2024') }}

UNION ALL

SELECT
    2025 AS year,
    {{ e_stat_economic_structure_industry_code(2025, 'cat01', "cat01_metadata->>'$.name'") }} AS business_code,
    {{ e_stat_economic_structure_industry_name(2025, "cat01_metadata->>'$.name'") }} AS business_name,
    tab AS cost_item_code,
    tab_metadata->>'$.name' AS tab_name,
    value
FROM {{ ref('raw_economic_structure_cost_2025') }}
)

SELECT
    year,
    business_code,
    business_name,
    cost_item_code,
    NULLIF(regexp_extract(tab_name, '^（(.*)）_', 1), '') AS cost_scope,
    regexp_replace(tab_name, '^（.*）_', '') AS cost_item,
    value AS share_percent
FROM unioned
