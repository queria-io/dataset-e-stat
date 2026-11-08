-- corporate_finance の2つの mart が、原典の構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 1. 対象業種の範囲（scope）と原数値・季節調整値の組がすべてあり、取り始めの期が tables.yml の
--    initial_time どおり（四半期は2008年4〜6月期、年度は2008年度）。季節調整値は全期間を取るので
--    1985年4〜6月期から。金融業、保険業以外の業種の原数値は、2007年度以前を手元から取り込んだ
--    後（local_tables.yml の corporate_finance_history）は四半期が1954年4〜6月期、年度が1960年度から。
--    最初の期から最後の期まで、四半期・年度の抜けが無い
-- 2. キー（scope・季節調整・調査項目・業種・資本金規模・期）が一意で、単位が空でない
-- 3. 金融業、保険業以外の業種の四半期（原数値・金額の項目）で、次の恒等式がちょうど成り立つ（実測で差0）。
--    内訳の規模・業種が無い組（業種 102・103 には 10億円以上が無い）はその内訳を0として足す。
--    資本金規模の式は1967年4〜6月期から（それより前は全規模が3区分の和にならない）。
--    合計の行が無い組は失敗にする
--    - 全規模（26）= 10億円以上（25）+ 1億円以上10億円未満（24）+ 1千万円以上1億円未満（19）
--    - 1億円以上（23）= 25 + 24
--    - 全産業（104）= 製造業（108）+ 非製造業（144）
-- 4. 全産業（金融業、保険業を含む）の母集団と経常利益が、金融業、保険業以外の業種の全産業（104）と
--    金融業、保険業の和にちょうど一致する（実測で差0）。範囲ごとの表の読み違いを見る

WITH q AS (
    SELECT * FROM {{ ref('quarterly_statements') }}
),

a AS (
    SELECT * FROM {{ ref('annual_statements') }}
),

expected_series (scope, seasonally_adjusted, first_time) AS (
    VALUES
        -- 2007年度以前を手元から取り込んだ後は、金融業、保険業以外の業種は全期間（1954年4〜6月期から）
        ('nonfinancial', false, '{{ "19542" if local_source_loaded("corporate_finance_nonfinancial_quarterly_pre2008") else "20082" }}'),
        ('nonfinancial', true, '19852'),
        ('all_industries', false, '20082'),
        ('finance_insurance', false, '20082'),
        ('banking', false, '20082'),
        ('nondeposit_credit', false, '20082'),
        ('securities', false, '20082'),
        ('other_securities', false, '20082'),
        ('insurance', false, '20082'),
        ('other_insurance', false, '20082')
),

quarter_series AS (
    SELECT scope, seasonally_adjusted, min(time) AS first_time,
        count(DISTINCT time) AS periods,
        (max(year) * 4 + max_by(quarter, time)) - (min(year) * 4 + min_by(quarter, time)) + 1 AS expected_periods
    FROM q
    GROUP BY scope, seasonally_adjusted
),

annual_series AS (
    SELECT scope, min(time) AS first_time, count(DISTINCT time) AS periods,
        max(fiscal_year) - min(fiscal_year) + 1 AS expected_periods
    FROM a
    GROUP BY scope
),

series_checks AS (
    SELECT 'quarterly series ' || e.scope || ' ' || e.seasonally_adjusted AS check_name,
        coalesce(s.first_time || ' / ' || s.periods, 'missing') AS actual,
        e.first_time || ' / ' || coalesce(s.expected_periods, 0) AS expected
    FROM expected_series e
    LEFT JOIN quarter_series s USING (scope, seasonally_adjusted)
    WHERE s.first_time IS DISTINCT FROM e.first_time OR s.periods <> s.expected_periods
    UNION ALL
    SELECT 'annual series ' || e.scope,
        coalesce(s.first_time || ' / ' || s.periods, 'missing'),
        e.first_time || ' / ' || coalesce(s.expected_periods, 0)
    FROM (
        SELECT DISTINCT scope,
            CASE WHEN scope = 'nonfinancial' THEN '{{ "19600" if local_source_loaded("corporate_finance_nonfinancial_annual_pre2008") else "20080" }}' ELSE '20080' END AS first_time
        FROM expected_series
    ) e
    LEFT JOIN annual_series s USING (scope)
    WHERE s.first_time IS DISTINCT FROM e.first_time OR s.periods <> s.expected_periods
    UNION ALL
    SELECT 'unexpected scope ' || scope || ' ' || seasonally_adjusted, '', ''
    FROM quarter_series
    WHERE (scope, seasonally_adjusted) NOT IN (SELECT (scope, seasonally_adjusted) FROM expected_series)
),

duplicates AS (
    SELECT 'quarterly duplicate ' || scope || ' ' || item_code || ' ' || industry_code || ' ' || size_code || ' ' || time AS check_name,
        count(*)::VARCHAR AS actual, '1' AS expected
    FROM q
    GROUP BY scope, seasonally_adjusted, item_code, industry_code, size_code, time
    HAVING count(*) > 1
    UNION ALL
    SELECT 'annual duplicate ' || scope || ' ' || item_code || ' ' || industry_code || ' ' || size_code || ' ' || time,
        count(*)::VARCHAR, '1'
    FROM a
    GROUP BY scope, item_code, industry_code, size_code, time
    HAVING count(*) > 1
),

missing_units AS (
    SELECT 'missing unit ' || scope || ' ' || item_code AS check_name, count(*)::VARCHAR AS actual, '0' AS expected
    FROM q
    WHERE unit IS NULL OR unit = ''
    GROUP BY scope, item_code
),

nonfinancial AS (
    SELECT item_code, industry_code, size_code, time, value
    FROM q
    WHERE scope = 'nonfinancial' AND NOT seasonally_adjusted AND unit = '百万円'
),

size_sums AS (
    SELECT 'size sum ' || item_code || ' ' || industry_code || ' ' || time AS check_name,
        (coalesce(s25, 0) + coalesce(s24, 0) + coalesce(s19, 0))::VARCHAR AS actual,
        coalesce(s26::VARCHAR, 'missing') AS expected
    FROM (
        SELECT item_code, industry_code, time,
            max(value) FILTER (WHERE size_code = '26') AS s26,
            max(value) FILTER (WHERE size_code = '25') AS s25,
            max(value) FILTER (WHERE size_code = '24') AS s24,
            max(value) FILTER (WHERE size_code = '19') AS s19,
            max(value) FILTER (WHERE size_code = '23') AS s23
        FROM nonfinancial
        GROUP BY item_code, industry_code, time
    )
    -- 1967年1〜3月期までは全規模が3区分の和にならない（実測）ので、それより後の期だけ見る
    WHERE time >= '19672'
        AND (NOT coalesce(abs(s26 - (coalesce(s25, 0) + coalesce(s24, 0) + coalesce(s19, 0))) <= 1, false)
            OR NOT coalesce(abs(s23 - (coalesce(s25, 0) + coalesce(s24, 0))) <= 1, true))
),

industry_sums AS (
    SELECT 'industry sum ' || item_code || ' ' || size_code || ' ' || time AS check_name,
        (coalesce(i108, 0) + coalesce(i144, 0))::VARCHAR AS actual,
        coalesce(i104::VARCHAR, 'missing') AS expected
    FROM (
        SELECT item_code, size_code, time,
            max(value) FILTER (WHERE industry_code = '104') AS i104,
            max(value) FILTER (WHERE industry_code = '108') AS i108,
            max(value) FILTER (WHERE industry_code = '144') AS i144
        FROM nonfinancial
        GROUP BY item_code, size_code, time
    )
    -- 全産業の行が無く、内訳も0の組（1959年の一部の項目）は数えない
    WHERE NOT coalesce(abs(i104 - (coalesce(i108, 0) + coalesce(i144, 0))) <= 1, i104 IS NULL AND coalesce(i108, 0) + coalesce(i144, 0) = 0)
),

scope_sums AS (
    SELECT 'all_industries = nonfinancial + finance_insurance ' || item || ' ' || size_code || ' ' || time AS check_name,
        (max(value) FILTER (WHERE scope = 'nonfinancial') + max(value) FILTER (WHERE scope = 'finance_insurance'))::VARCHAR AS actual,
        max(value) FILTER (WHERE scope = 'all_industries')::VARCHAR AS expected
    FROM q
    WHERE NOT seasonally_adjusted
        AND item IN ('母集団(当期末)', '経常利益(当期末)')
        AND scope IN ('all_industries', 'nonfinancial', 'finance_insurance')
        AND (scope <> 'nonfinancial' OR industry_code = '104')
        AND size_code IN (SELECT size_code FROM q WHERE scope = 'all_industries')
        -- 全産業（金融業、保険業を含む）の表は2008年4〜6月期から
        AND time >= '20082'
    GROUP BY item, size_code, time
    HAVING NOT coalesce(abs(max(value) FILTER (WHERE scope = 'all_industries')
        - (max(value) FILTER (WHERE scope = 'nonfinancial') + max(value) FILTER (WHERE scope = 'finance_insurance'))) <= 1, false)
)

SELECT * FROM series_checks
UNION ALL SELECT * FROM duplicates
UNION ALL SELECT * FROM missing_units
UNION ALL SELECT * FROM size_sums
UNION ALL SELECT * FROM industry_sums
UNION ALL SELECT * FROM scope_sums
