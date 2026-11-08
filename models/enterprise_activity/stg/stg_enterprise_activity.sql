{# 経済産業省企業活動基本調査（2020〜2025年調査）の表を1つに積み、行の軸を読み分ける。

   どの表も cat01=表頭（測定項目）、cat02=表側の2軸で、表側は「産業コード_産業名_内訳_年度」の
   ように項目を「_」でつないだ名称になっている。並びは表の種類（kind）で決まる。
   - summary / research / foreign: 産業コード_産業名_年度
   - prefecture / capital_*: 産業コード_産業名_[内訳コード_]内訳名_年度。2020・2021年の表は
     内訳コードが無いので、2022年以降の表で同じ名前に付いたコードを引く
   - subsidiary: 産業コード_産業名_子会社業種コード_子会社業種名_年度
   表側の先頭には全体（総合計）の過去5年度の行が並び、最新年度の総合計の行は2回出る。
   summary だけは全産業について過去5年度の行を持つ。

   測定項目は「資産_流動資産_百万円」のように末尾が単位なので、単位を unit に分ける。 #}
WITH unioned AS (
    SELECT 'summary' AS kind, 2020 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2020') }}
    UNION ALL
    SELECT 'summary' AS kind, 2021 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2021') }}
    UNION ALL
    SELECT 'summary' AS kind, 2022 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2022') }}
    UNION ALL
    SELECT 'summary' AS kind, 2023 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2023') }}
    UNION ALL
    SELECT 'summary' AS kind, 2024 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2024') }}
    UNION ALL
    SELECT 'summary' AS kind, 2025 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2025') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2020 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2020') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2021 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2021') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2022 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2022') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2023 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2023') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2024 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2024') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2025 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2025') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2020 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2020') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2021 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2021') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2022 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2022') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2023 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2023') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2024 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2024') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2025 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2025') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2020 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2020') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2021 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2021') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2022 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2022') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2023 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2023') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2024 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2024') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2025 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2025') }}
    UNION ALL
    SELECT 'research' AS kind, 2020 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2020') }}
    UNION ALL
    SELECT 'research' AS kind, 2021 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2021') }}
    UNION ALL
    SELECT 'research' AS kind, 2022 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2022') }}
    UNION ALL
    SELECT 'research' AS kind, 2023 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2023') }}
    UNION ALL
    SELECT 'research' AS kind, 2024 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2024') }}
    UNION ALL
    SELECT 'research' AS kind, 2025 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2025') }}
    UNION ALL
    SELECT 'foreign' AS kind, 2020 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_foreign_2020') }}
    UNION ALL
    SELECT 'foreign' AS kind, 2021 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_foreign_2021') }}
    UNION ALL
    SELECT 'foreign' AS kind, 2022 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_foreign_2022') }}
    UNION ALL
    SELECT 'foreign' AS kind, 2023 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_foreign_2023') }}
    UNION ALL
    SELECT 'foreign' AS kind, 2024 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_foreign_2024') }}
    UNION ALL
    SELECT 'foreign' AS kind, 2025 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_foreign_2025') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2020 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2020') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2021 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2021') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2022 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2022') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2023 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2023') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2024 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2024') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2025 AS survey_year, cat01, cat02,
        cat01_metadata->>'$.name' AS measure_label, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2025') }}
),

parsed AS (
    SELECT
        kind,
        survey_year,
        cat01 AS measure_code,
        regexp_replace(measure_label, '_[^_]+$', '') AS measure,
        regexp_extract(measure_label, '_([^_]+)$', 1) AS unit,
        cat02,
        string_split(row_label, '_') AS parts,
        value
    FROM unioned
),

split AS (
    SELECT
        *,
        len(parts) AS n_parts,
        CAST(regexp_extract(parts[-1], '^(\d{4})年度$', 1) AS INTEGER) AS fiscal_year,
        parts[1] AS industry_code,
        parts[2] AS industry_name,
        CASE
            WHEN kind = 'subsidiary' THEN parts[3]
            WHEN kind IN ('prefecture', 'capital_balance', 'capital_business') AND len(parts) = 5 THEN parts[3]
        END AS breakdown_code_raw,
        CASE
            WHEN kind IN ('subsidiary', 'prefecture', 'capital_balance', 'capital_business') THEN parts[-2]
        END AS breakdown_name
    FROM parsed
),

breakdown_codes AS (
    SELECT DISTINCT
        CASE WHEN kind LIKE 'capital_%' THEN 'capital' ELSE kind END AS kind_group,
        breakdown_name,
        breakdown_code_raw AS breakdown_code
    FROM split
    WHERE breakdown_code_raw IS NOT NULL AND kind IN ('prefecture', 'capital_balance', 'capital_business')
)

SELECT
    s.kind,
    s.survey_year,
    s.fiscal_year,
    s.industry_code,
    s.industry_name,
    COALESCE(s.breakdown_code_raw, b.breakdown_code) AS breakdown_code,
    s.breakdown_name,
    s.measure_code,
    s.measure,
    s.unit,
    s.value
FROM split s
LEFT JOIN breakdown_codes b
    ON b.kind_group = CASE WHEN s.kind LIKE 'capital_%' THEN 'capital' ELSE s.kind END
    AND b.breakdown_name = s.breakdown_name
    AND s.breakdown_code_raw IS NULL
-- 最新年度の総合計の行は表側に2回出る（過去5年度の並びの最後と、内訳の先頭）。値は同じなので1行にする
QUALIFY row_number() OVER (
    PARTITION BY s.kind, s.survey_year, s.fiscal_year, s.industry_code, s.breakdown_name, s.measure_code
    ORDER BY s.cat02
) = 1
