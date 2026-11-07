-- economic_structure の3つの mart が、原典の構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 1. 調査年がそろっている（企業産業・費用内訳は 2019・2020・2022〜2025年、事業所は 2022〜2025年）
-- 2. どの行も表章項目（measure_code）と産業の段（industry_level）が決まる。表章項目のコードは年で
--    振り直されるので、マッピングから漏れると measure_code が NULL になる
-- 3. 企業産業: キー（年・産業・経営組織・表章項目）が一意。総数の経営組織（0）は 1（会社企業）と
--    2（会社以外の法人）の和に、全産業は大分類の和に一致する。原典は区分ごとに丸めるうえ秘匿もあるので、
--    0.1% までのずれを許す（実測の最大は全産業の売上で 0.0006%）
-- 4. 費用内訳: 事業区分ごとに割合の和が100%（実測で 100 ± 1e-13）
-- 5. 事業所: 全国の事業所数は都道府県の和に一致する（実測で全年・全産業ちょうど）
--
-- 元表は手元でだけ取り込む (load_local.py economic_structure)。元表が無いカタログ
-- (CI でまだ公開していないとき) では 0 行の表になるので検査しない。

{% if local_source_loaded('economic_structure_enterprise_2025') %}
WITH enterprise AS (
    SELECT * FROM {{ ref('enterprise_industry') }}
),

cost AS (
    SELECT * FROM {{ ref('cost_composition') }}
),

establishment AS (
    SELECT * FROM {{ ref('establishment_prefecture') }}
),

years AS (
    SELECT 'enterprise_industry years' AS check_name,
        string_agg(DISTINCT year::VARCHAR, ',' ORDER BY year::VARCHAR) AS actual,
        '2019,2020,2022,2023,2024,2025' AS expected
    FROM enterprise
    UNION ALL
    SELECT 'cost_composition years',
        string_agg(DISTINCT year::VARCHAR, ',' ORDER BY year::VARCHAR),
        '2019,2020,2022,2023,2024,2025'
    FROM cost
    UNION ALL
    SELECT 'establishment_prefecture years',
        string_agg(DISTINCT year::VARCHAR, ',' ORDER BY year::VARCHAR),
        '2022,2023,2024,2025'
    FROM establishment
),

unmapped AS (
    SELECT 'enterprise_industry unmapped measure ' || year AS check_name,
        count(*)::VARCHAR AS actual, '0' AS expected
    FROM enterprise
    WHERE measure_code IS NULL OR industry_code IS NULL OR industry_level IS NULL
    GROUP BY year
),

duplicates AS (
    SELECT 'enterprise_industry duplicate ' || year || ' ' || industry_code || ' ' || organization_code || ' ' || measure_code AS check_name,
        count(*)::VARCHAR AS actual, '1' AS expected
    FROM enterprise
    GROUP BY year, industry_code, organization_code, measure_code
    HAVING count(*) > 1
),

organization_sums AS (
    SELECT 'enterprise_industry organization ' || year || ' ' || industry_code || ' ' || measure_code AS check_name,
        sum(value) FILTER (WHERE organization_code IN ('1', '2'))::VARCHAR AS actual,
        max(value) FILTER (WHERE organization_code = '0')::VARCHAR AS expected
    FROM enterprise
    WHERE industry_level = 'total'
    GROUP BY year, industry_code, measure_code
    HAVING abs(sum(value) FILTER (WHERE organization_code IN ('1', '2'))
        - max(value) FILTER (WHERE organization_code = '0'))
        > 0.001 * max(value) FILTER (WHERE organization_code = '0')
),

division_sums AS (
    SELECT 'enterprise_industry divisions ' || year || ' ' || measure_code AS check_name,
        sum(value) FILTER (WHERE industry_level = 'division')::VARCHAR AS actual,
        max(value) FILTER (WHERE industry_level = 'total')::VARCHAR AS expected
    FROM enterprise
    WHERE organization_code = '0'
    GROUP BY year, measure_code
    HAVING abs(sum(value) FILTER (WHERE industry_level = 'division')
        - max(value) FILTER (WHERE industry_level = 'total'))
        > 0.001 * max(value) FILTER (WHERE industry_level = 'total')
),

cost_sums AS (
    SELECT 'cost_composition sum ' || year || ' ' || business_code AS check_name,
        sum(share_percent)::VARCHAR AS actual, '100' AS expected
    FROM cost
    GROUP BY year, business_code
    HAVING abs(sum(share_percent) - 100) > 0.01
),

prefecture_sums AS (
    SELECT 'establishment_prefecture prefectures ' || year || ' ' || industry_code AS check_name,
        sum(establishments) FILTER (WHERE area_level = 'prefecture')::VARCHAR AS actual,
        max(establishments) FILTER (WHERE area_level = 'national')::VARCHAR AS expected
    FROM establishment
    GROUP BY year, industry_code
    HAVING count(*) FILTER (WHERE area_level = 'prefecture') <> 47
        OR sum(establishments) FILTER (WHERE area_level = 'prefecture')
            IS DISTINCT FROM max(establishments) FILTER (WHERE area_level = 'national')
)

SELECT * FROM years WHERE actual IS DISTINCT FROM expected
UNION ALL SELECT * FROM unmapped WHERE actual <> expected
UNION ALL SELECT * FROM duplicates
UNION ALL SELECT * FROM organization_sums
UNION ALL SELECT * FROM division_sums
UNION ALL SELECT * FROM cost_sums
UNION ALL SELECT * FROM prefecture_sums
{% else %}
SELECT NULL::VARCHAR AS check_name, NULL::VARCHAR AS actual, NULL::VARCHAR AS expected
WHERE FALSE
{% endif %}
