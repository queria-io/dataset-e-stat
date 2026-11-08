{# 経済構造実態調査 事業所に関する集計1（産業大分類別事業所数及び売上（収入）金額、全国・
   都道府県）を調査年ごとの表から積み、表章項目を列に広げる。表章項目は 011=事業所数、
   02=売上（収入）金額（百万円）。 #}
WITH unioned AS (
SELECT
    2022 AS year,
    area,
    area_metadata->>'$.name' AS area_name,
    {{ e_stat_economic_structure_industry_code(2022, 'cat01', "cat01_metadata->>'$.name'") }} AS industry_code,
    {{ e_stat_economic_structure_industry_name(2022, "cat01_metadata->>'$.name'") }} AS industry_name,
    tab,
    value
FROM {{ ref('raw_economic_structure_establishment_2022') }}

UNION ALL

SELECT
    2023 AS year,
    area,
    area_metadata->>'$.name' AS area_name,
    {{ e_stat_economic_structure_industry_code(2023, 'cat01', "cat01_metadata->>'$.name'") }} AS industry_code,
    {{ e_stat_economic_structure_industry_name(2023, "cat01_metadata->>'$.name'") }} AS industry_name,
    tab,
    value
FROM {{ ref('raw_economic_structure_establishment_2023') }}

UNION ALL

SELECT
    2024 AS year,
    area,
    area_metadata->>'$.name' AS area_name,
    {{ e_stat_economic_structure_industry_code(2024, 'cat01', "cat01_metadata->>'$.name'") }} AS industry_code,
    {{ e_stat_economic_structure_industry_name(2024, "cat01_metadata->>'$.name'") }} AS industry_name,
    tab,
    value
FROM {{ ref('raw_economic_structure_establishment_2024') }}

UNION ALL

SELECT
    2025 AS year,
    area,
    area_metadata->>'$.name' AS area_name,
    {{ e_stat_economic_structure_industry_code(2025, 'cat01', "cat01_metadata->>'$.name'") }} AS industry_code,
    {{ e_stat_economic_structure_industry_name(2025, "cat01_metadata->>'$.name'") }} AS industry_name,
    tab,
    value
FROM {{ ref('raw_economic_structure_establishment_2025') }}
)

SELECT
    year,
    area,
    area_name,
    CASE WHEN area = '00000' THEN 'national' ELSE 'prefecture' END AS area_level,
    industry_code,
    industry_name,
    {{ e_stat_economic_structure_industry_level('industry_code') }} AS industry_level,
    max(value) FILTER (WHERE tab = '011') AS establishments,
    max(value) FILTER (WHERE tab = '02') AS sales_million_yen
FROM unioned
GROUP BY ALL
