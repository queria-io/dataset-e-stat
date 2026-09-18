-- local_finance の2つの mart が、原典の構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 原典は列名に番号を持つ CSV で、1ファイルに当年度(行番号1)と前年度(行番号2)の
-- 2ブロックが縦に並ぶ。ブロックの取り違えも列のずれも、値の見た目は正しいまま
-- 起きるので、収支の恒等式と合計行との突き合わせで落とす。
--
-- 収支の恒等式は原典の側に合わない行が7行ある（実測: 156,892行中。2012年度の世田谷区、
-- 2023年度の諏訪広域公立大学事務組合と宇和島地区広域事務組合、2024年度の川南町と、
-- それぞれを含む合計の行3本）。件数の割合で許すと、都道府県分のように行数の少ない
-- 調査表が1年度まるごとずれても全体の0.03%にしかならず通ってしまう。7行を年度と
-- 団体で名指しし、それ以外が1行でも出たら落とす。原典が新しいずれを増やした年は
-- ここが赤くなるので、値を見てから足す。
--
-- 合計(全国)の行は、その調査表に載る全団体の単純合計に一致する（実測: 1989〜2024年度の
-- 全年度・両調査表で差0）。前年度ブロックを混ぜると合計だけが倍になるので、これが
-- ブロック取り違えの一番効く検査になる。

{% set known_identity_gaps = [
    (2012, 'municipality', 'total'),
    (2012, 'municipality', '131121'),
    (2023, 'municipality', 'total'),
    (2023, 'municipality', '209554'),
    (2023, 'municipality', '388882'),
    (2024, 'municipality', 'total'),
    (2024, 'municipality', '454052'),
] %}

WITH expected_years AS (
    SELECT UNNEST(RANGE(1989, (SELECT MAX(fiscal_year) FROM {{ ref('settlement_balance') }}) + 1))
        AS fiscal_year
),

identity_violations AS (
    SELECT fiscal_year, survey_scope, COALESCE(lg_code, 'total') AS entity
    FROM {{ ref('settlement_balance') }}
    WHERE balance <> revenue_total - expenditure_total
        OR real_balance <> balance - carryover_resources
        OR real_single_year_balance <> single_year_balance + reserve_fund
            + early_redemption - reserve_fund_drawdown
),

known_identity_gaps AS (
    SELECT * FROM (VALUES
        {%- for year, scope, entity in known_identity_gaps %}
        ({{ year }}, '{{ scope }}', '{{ entity }}'){{ "," if not loop.last }}
        {%- endfor %}
    ) AS t(fiscal_year, survey_scope, entity)
),

-- 年度 × 調査表の組を期待の側から並べる。行の側から GROUP BY すると、ある年度の
-- 調査表が丸ごと消えたときにグループが生まれず、0行 = 合格を返して素通りする。
expected_scopes AS (
    SELECT e.fiscal_year, s.survey_scope
    FROM expected_years e
    CROSS JOIN (VALUES ('prefecture'), ('municipality')) AS s(survey_scope)
),

scope_counts AS (
    SELECT x.fiscal_year, x.survey_scope,
        COUNT(b.fiscal_year) AS rows,
        COUNT(*) FILTER (WHERE b.entity_kind = 'total') AS totals,
        COUNT(*) FILTER (WHERE b.entity_kind = 'prefecture') AS prefectures
    FROM expected_scopes x
    LEFT JOIN {{ ref('settlement_balance') }} b
        ON b.fiscal_year = x.fiscal_year AND b.survey_scope = x.survey_scope
    GROUP BY x.fiscal_year, x.survey_scope
),

entity_sums AS (
    SELECT fiscal_year, survey_scope,
        SUM(revenue_total) AS revenue_total,
        SUM(expenditure_total) AS expenditure_total,
        SUM(real_balance) AS real_balance
    FROM {{ ref('settlement_balance') }}
    WHERE entity_kind <> 'total'
    GROUP BY fiscal_year, survey_scope
),

-- 合計の行の側から外側結合する。内部結合にすると、ある年の団体行が丸ごと消えた
-- ときにグループが生まれず、0行 = 合格を返して素通りする。
totals AS (
    SELECT t.fiscal_year, t.survey_scope,
        t.revenue_total AS total_revenue, e.revenue_total AS sum_revenue,
        t.expenditure_total AS total_expenditure, e.expenditure_total AS sum_expenditure,
        t.real_balance AS total_real_balance, e.real_balance AS sum_real_balance
    FROM {{ ref('settlement_balance') }} t
    LEFT JOIN entity_sums e USING (fiscal_year, survey_scope)
    WHERE t.entity_kind = 'total'
),

capacity_years AS (
    SELECT fiscal_year,
        COUNT(*) AS rows,
        COUNT(DISTINCT lg_code) AS entities,
        COUNT(DISTINCT LEFT(area_code, 2)) AS prefs
    FROM {{ ref('fiscal_capacity') }}
    GROUP BY fiscal_year
),

-- EXCEPT は UNION ALL と同じ優先順位で左から結合するので、下の並びに直接
-- 書くとそれまでの検査結果ごと引かれる。CTE に閉じ込める。
unexpected_identity_gaps AS (
    SELECT * FROM identity_violations
    EXCEPT ALL
    SELECT * FROM known_identity_gaps
),

repaired_identity_gaps AS (
    SELECT * FROM known_identity_gaps
    EXCEPT ALL
    SELECT * FROM identity_violations
)

SELECT '決算収支の行が無い、または収録が1989年度から始まっていない' AS violation,
    COALESCE(CAST(min_year AS VARCHAR), 'empty') AS detail
FROM (
    SELECT COUNT(*) AS rows, MIN(fiscal_year) AS min_year
    FROM {{ ref('settlement_balance') }}
)
WHERE rows = 0 OR min_year <> 1989

UNION ALL

SELECT '収録されていない年度がある', CAST(e.fiscal_year AS VARCHAR)
FROM expected_years e
LEFT JOIN (SELECT DISTINCT fiscal_year FROM {{ ref('settlement_balance') }}) y
    USING (fiscal_year)
WHERE y.fiscal_year IS NULL

UNION ALL

SELECT '年度×調査表×団体コードが一意でない',
    CAST(fiscal_year AS VARCHAR) || ' ' || survey_scope || ' ' || lg_code
FROM {{ ref('settlement_balance') }}
WHERE lg_code IS NOT NULL
GROUP BY fiscal_year, survey_scope, lg_code
HAVING COUNT(*) > 1

UNION ALL

SELECT '年度×調査表の行が無い、または合計(全国)が1本ずつ入っていない',
    CAST(fiscal_year AS VARCHAR) || ' ' || survey_scope
        || ' 行' || CAST(rows AS VARCHAR) || ' 合計' || CAST(totals AS VARCHAR)
FROM scope_counts
WHERE rows = 0 OR totals <> 1

UNION ALL

SELECT '都道府県の行が47件そろっていない',
    CAST(fiscal_year AS VARCHAR) || ' ' || CAST(prefectures AS VARCHAR)
FROM scope_counts
WHERE survey_scope = 'prefecture' AND prefectures <> 47

UNION ALL

SELECT '合計(全国) <> その調査表の団体の和',
    CAST(fiscal_year AS VARCHAR) || ' ' || survey_scope
FROM totals
WHERE sum_revenue IS NULL
    OR total_revenue <> sum_revenue
    OR total_expenditure <> sum_expenditure
    OR total_real_balance <> sum_real_balance

UNION ALL

SELECT '収支の恒等式が既知の7行以外で合わない',
    CAST(fiscal_year AS VARCHAR) || ' ' || survey_scope || ' ' || entity
FROM unexpected_identity_gaps

UNION ALL

SELECT '既知の恒等式のずれが直っている（名指しを外す）',
    CAST(fiscal_year AS VARCHAR) || ' ' || survey_scope || ' ' || entity
FROM repaired_identity_gaps

UNION ALL

SELECT '財政力指数が取りうる範囲を外れている',
    CAST(fiscal_year AS VARCHAR) || ' ' || lg_code || ' '
        || CAST(fiscal_capacity_index AS VARCHAR)
FROM {{ ref('fiscal_capacity') }}
WHERE fiscal_capacity_index IS NULL
    OR fiscal_capacity_index <= 0
    OR fiscal_capacity_index > 5

UNION ALL

SELECT '財政力の年度が2014年度から始まっていない、または年度に欠けがある',
    CAST(min_year AS VARCHAR) || '-' || CAST(max_year AS VARCHAR)
        || ' ' || CAST(n AS VARCHAR) || '年度'
FROM (
    SELECT MIN(fiscal_year) AS min_year, MAX(fiscal_year) AS max_year,
        COUNT(DISTINCT fiscal_year) AS n
    FROM {{ ref('fiscal_capacity') }}
)
WHERE min_year <> 2014 OR n <> max_year - min_year + 1

UNION ALL

-- 市区町村数は年度で動きうるので固定値では見ない。団体コードの重複と、
-- 47都道府県がそろうことだけを見る。
SELECT '財政力の団体コードが年度内で重複している、または都道府県が47そろわない',
    CAST(fiscal_year AS VARCHAR) || ' 行' || CAST(rows AS VARCHAR)
        || ' 団体' || CAST(entities AS VARCHAR)
        || ' 都道府県' || CAST(prefs AS VARCHAR)
FROM capacity_years
WHERE rows <> entities OR prefs <> 47

UNION ALL

SELECT '財政力に市区町村でない団体が混じっている',
    CAST(fiscal_year AS VARCHAR) || ' ' || lg_code || ' ' || COALESCE(entity_name, '')
FROM {{ ref('fiscal_capacity') }}
WHERE SUBSTR(lg_code, 3, 1) IN ('8', '9')
