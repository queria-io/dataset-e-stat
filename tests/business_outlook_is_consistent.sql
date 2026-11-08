-- business_outlook の2つの mart が、原典の構造どおりに読めていることを検証する。結果が0行ならテスト成功。
--
-- 1. BSI は4つの指標とも、2004年4〜6月期から最新の調査期まで四半期の抜けが無い
-- 2. キーが一意（BSI: 調査期・指標・当期翌期・規模・業種、見通し: 調査期・表・年度・期・業種・項目・表章項目）
-- 3. BSI は -100〜100 の範囲（上昇と回答した割合 - 下降と回答した割合）
-- 4. 翌年度見通しの表は1〜3月期の調査にだけあり、年度の読み替え（相対の年度 → 実際の年度）が
--    調査期と合っている。調査期ごとの通期の最も新しい年度が、当年度見通しの表では調査年
--    （1〜3月期の調査は調査年の前年）、翌年度見通しの表では調査年にちょうど一致する
--
-- 元表は手元でだけ取り込む (load_local.py business_outlook)。元表が無いカタログ
-- (CI でまだ公開していないとき) では 0 行の表になるので検査しない。

{% if local_source_loaded('business_outlook_conditions_bsi') %}
WITH bsi AS (
    SELECT * FROM {{ ref('bsi') }}
),

outlook AS (
    SELECT * FROM {{ ref('sales_profit_investment_outlook') }}
),

quarters AS (
    SELECT indicator,
        count(DISTINCT survey_time) AS n,
        (max(survey_year) * 4 + max_by(survey_quarter, survey_time)) - (min(survey_year) * 4 + min_by(survey_quarter, survey_time)) + 1 AS expected,
        min(survey_time) AS first_time
    FROM bsi
    GROUP BY indicator
)

SELECT 'indicators' AS check_name, count(*)::VARCHAR AS actual, '4' AS expected
FROM quarters HAVING count(*) <> 4

UNION ALL
SELECT 'quarters ' || indicator, n || ' from ' || first_time, expected || ' from 2004000406'
FROM quarters WHERE n <> expected OR first_time <> '2004000406'

UNION ALL
SELECT 'bsi duplicate', count(*)::VARCHAR, '0'
FROM (SELECT 1 FROM bsi GROUP BY survey_time, indicator, horizon_code, size_code, industry_code HAVING count(*) > 1)
HAVING count(*) > 0

UNION ALL
SELECT 'outlook duplicate', count(*)::VARCHAR, '0'
FROM (SELECT 1 FROM outlook GROUP BY survey_time, outlook_table, fiscal_year, half, industry_code, item, measure HAVING count(*) > 1)
HAVING count(*) > 0

UNION ALL
SELECT 'bsi out of range', count(*)::VARCHAR, '0'
FROM bsi WHERE value < -100 OR value > 100
HAVING count(*) > 0

UNION ALL
SELECT 'next-year table outside Jan-Mar', count(*)::VARCHAR, '0'
FROM outlook WHERE outlook_table = '翌年度見通し' AND survey_quarter <> 1
HAVING count(*) > 0

UNION ALL
SELECT 'fiscal year ' || outlook_table || ' ' || survey_time,
    max(fiscal_year)::VARCHAR,
    max(CASE WHEN outlook_table = '翌年度見通し' THEN survey_year
        ELSE survey_year - CASE WHEN survey_quarter = 1 THEN 1 ELSE 0 END END)::VARCHAR
FROM outlook
WHERE half = '通期'
GROUP BY outlook_table, survey_time
HAVING max(fiscal_year) <> max(CASE WHEN outlook_table = '翌年度見通し' THEN survey_year
    ELSE survey_year - CASE WHEN survey_quarter = 1 THEN 1 ELSE 0 END END)
{% else %}
SELECT NULL::VARCHAR AS check_name, NULL::VARCHAR AS actual, NULL::VARCHAR AS expected
WHERE FALSE
{% endif %}
