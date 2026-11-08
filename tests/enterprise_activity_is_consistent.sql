-- enterprise_activity の mart が、原典の構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 1. 表の種類ごとに 2020〜2025年の調査がそろい、どの行も年度と（内訳のある表は）内訳コードが読める。
--    2010〜2019年調査（stg_enterprise_activity_legacy）を取り込んだ後は、そちらの行も産業コード・
--    内訳コード・測定項目が読める
-- 2. mart のキーが一意
-- 3. 企業数で次の恒等式がちょうど成り立つ（実測で全年度・差0）
--    - 産業: 合計（000）= 大分類（C・E・F・G・I1・I2・J1・K1・L・M・N・O・R1）の和、
--      総合計 = 合計（000）+ サービス業（その他のサービス業）（R2）+ その他の産業（Z）
--    - 都道府県: 全国（00000）= 47都道府県の和（企業数・事業所数）。秘匿で空欄の県がある年度は、和が全国を超えないこと
--    - 資本金規模: 計（00）= 8区分の和
--    表側の名称を「_」で区切る位置を読み違えると、産業・内訳・年度がずれてこれらが外れる
--
-- 元表は手元でだけ取り込む (load_local.py enterprise_activity)。元表が無いカタログ
-- (CI でまだ公開していないとき) では 0 行の表になるので検査しない。

{% if local_source_loaded('enterprise_activity_summary_2025') %}
{# 2010〜2019年調査（enterprise_activity_legacy）を取り込んだ後は、年度の数が増える #}
{% set legacy = local_source_loaded('enterprise_activity_summary_2010') %}
WITH stg AS (
    SELECT * FROM {{ ref('stg_enterprise_activity') }}
),

coverage AS (
    SELECT 'surveys ' || kind AS check_name,
        string_agg(DISTINCT survey_year::VARCHAR, ',' ORDER BY survey_year::VARCHAR) AS actual,
        '2020,2021,2022,2023,2024,2025' AS expected
    FROM stg
    GROUP BY kind
    HAVING string_agg(DISTINCT survey_year::VARCHAR, ',' ORDER BY survey_year::VARCHAR) <> '2020,2021,2022,2023,2024,2025'
    UNION ALL
    SELECT 'kinds', count(DISTINCT kind)::VARCHAR, '7' FROM stg HAVING count(DISTINCT kind) <> 7
    UNION ALL
    SELECT 'unparsed ' || kind || ' ' || survey_year, count(*)::VARCHAR, '0'
    FROM stg
    WHERE fiscal_year IS NULL OR industry_code IS NULL OR unit IS NULL
        OR (kind IN ('prefecture', 'capital_balance', 'capital_business', 'subsidiary') AND breakdown_code IS NULL)
    GROUP BY kind, survey_year
    {% if legacy %}
    UNION ALL
    SELECT 'unparsed legacy ' || kind || ' ' || survey_year, count(*)::VARCHAR, '0'
    FROM {{ ref('stg_enterprise_activity_legacy') }}
    WHERE fiscal_year IS NULL OR industry_code IS NULL OR measure IS NULL
        OR (kind IN ('prefecture', 'capital_balance', 'capital_business', 'subsidiary') AND breakdown_code IS NULL)
    GROUP BY kind, survey_year
    {% endif %}
),

duplicates AS (
    SELECT 'industry_finance duplicate' AS check_name, count(*)::VARCHAR AS actual, '0' AS expected
    FROM (SELECT 1 FROM {{ ref('industry_finance') }} GROUP BY fiscal_year, industry_code, measure_code HAVING count(*) > 1)
    HAVING count(*) > 0
    UNION ALL
    SELECT 'prefecture_finance duplicate', count(*)::VARCHAR, '0'
    FROM (SELECT 1 FROM {{ ref('prefecture_finance') }} GROUP BY fiscal_year, industry_code, area, measure_code HAVING count(*) > 1)
    HAVING count(*) > 0
    UNION ALL
    SELECT 'capital_size_finance duplicate', count(*)::VARCHAR, '0'
    FROM (SELECT 1 FROM {{ ref('capital_size_finance') }} GROUP BY fiscal_year, industry_code, capital_size_code, measure HAVING count(*) > 1)
    HAVING count(*) > 0
    UNION ALL
    SELECT 'research_development duplicate', count(*)::VARCHAR, '0'
    FROM (SELECT 1 FROM {{ ref('research_development') }} GROUP BY fiscal_year, industry_code, measure_code HAVING count(*) > 1)
    HAVING count(*) > 0
    UNION ALL
    SELECT 'foreign_affiliated_finance duplicate', count(*)::VARCHAR, '0'
    FROM (SELECT 1 FROM {{ ref('foreign_affiliated_finance') }} GROUP BY fiscal_year, industry_code, measure_code HAVING count(*) > 1)
    HAVING count(*) > 0
    UNION ALL
    SELECT 'subsidiary_count duplicate', count(*)::VARCHAR, '0'
    FROM (SELECT 1 FROM {{ ref('subsidiary_count') }} GROUP BY fiscal_year, industry_code, subsidiary_industry_code, measure_code HAVING count(*) > 1)
    HAVING count(*) > 0
),

industry AS (
    SELECT fiscal_year,
        max(value) FILTER (WHERE industry_code = '総合計') AS grand_total,
        max(value) FILTER (WHERE industry_code = '000') AS total,
        sum(value) FILTER (WHERE industry_code IN ('C', 'E', 'F', 'G', 'I1', 'I2', 'J1', 'K1', 'L', 'M', 'N', 'O', 'R1')) AS divisions,
        max(value) FILTER (WHERE industry_code = 'R2') AS r2,
        max(value) FILTER (WHERE industry_code = 'Z') AS z
    FROM {{ ref('industry_finance') }}
    WHERE measure = '企業数'
    GROUP BY fiscal_year
),

industry_sums AS (
    SELECT 'industry ' || fiscal_year AS check_name,
        divisions || ' / ' || (total + r2 + z) AS actual,
        total || ' / ' || grand_total AS expected
    FROM industry
    WHERE divisions IS DISTINCT FROM total OR (total + r2 + z) IS DISTINCT FROM grand_total
),

prefecture_sums AS (
    SELECT 'prefecture ' || fiscal_year || ' ' || measure AS check_name,
        sum(value) FILTER (WHERE area <> '00000')::VARCHAR AS actual,
        max(value) FILTER (WHERE area = '00000')::VARCHAR AS expected
    FROM {{ ref('prefecture_finance') }}
    WHERE industry_code = '総合計' AND measure IN ('企業数', '事業所数')
    GROUP BY fiscal_year, measure
    HAVING count(*) FILTER (WHERE area <> '00000') <> 47
        -- 秘匿で空欄の県がある年度（2013年度の事業所数など）は、和が全国を超えないことだけを見る
        OR (count(value) FILTER (WHERE area <> '00000') = 47
            AND sum(value) FILTER (WHERE area <> '00000') IS DISTINCT FROM max(value) FILTER (WHERE area = '00000'))
        OR sum(value) FILTER (WHERE area <> '00000') > max(value) FILTER (WHERE area = '00000')
),

capital_sums AS (
    SELECT 'capital ' || fiscal_year AS check_name,
        sum(value) FILTER (WHERE capital_size_code <> '00')::VARCHAR AS actual,
        max(value) FILTER (WHERE capital_size_code = '00')::VARCHAR AS expected
    FROM {{ ref('capital_size_finance') }}
    WHERE industry_code = '総合計' AND measure = '企業数'
    GROUP BY fiscal_year
    HAVING count(*) FILTER (WHERE capital_size_code <> '00') <> 8
        OR sum(value) FILTER (WHERE capital_size_code <> '00') IS DISTINCT FROM max(value) FILTER (WHERE capital_size_code = '00')
),

year_counts AS (
    SELECT 'fiscal years ' || name AS check_name, n::VARCHAR AS actual, expected::VARCHAR AS expected
    FROM (
        SELECT 'industry_finance' AS name, count(DISTINCT fiscal_year) AS n, {{ 20 if legacy else 10 }} AS expected FROM {{ ref('industry_finance') }}
        UNION ALL SELECT 'prefecture_finance', count(DISTINCT fiscal_year), {{ 16 if legacy else 6 }} FROM {{ ref('prefecture_finance') }}
        UNION ALL SELECT 'capital_size_finance', count(DISTINCT fiscal_year), {{ 16 if legacy else 6 }} FROM {{ ref('capital_size_finance') }}
        UNION ALL SELECT 'research_development', count(DISTINCT fiscal_year), {{ 16 if legacy else 6 }} FROM {{ ref('research_development') }}
        UNION ALL SELECT 'foreign_affiliated_finance', count(DISTINCT fiscal_year), {{ 11 if legacy else 6 }} FROM {{ ref('foreign_affiliated_finance') }}
        UNION ALL SELECT 'subsidiary_count', count(DISTINCT fiscal_year), {{ 16 if legacy else 6 }} FROM {{ ref('subsidiary_count') }}
    )
    WHERE n <> expected
)

SELECT * FROM coverage
UNION ALL SELECT * FROM duplicates
UNION ALL SELECT * FROM industry_sums
UNION ALL SELECT * FROM prefecture_sums
UNION ALL SELECT * FROM capital_sums
UNION ALL SELECT * FROM year_counts
{% else %}
SELECT NULL::VARCHAR AS check_name, NULL::VARCHAR AS actual, NULL::VARCHAR AS expected
WHERE FALSE
{% endif %}
