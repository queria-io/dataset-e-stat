-- job_placement の 2 テーブルが、原典の構造どおりに読めていることを検証する。結果が0行ならテスト成功。
--
-- 1. 月次は受理地別が1963年1月から、就業地別が2005年2月から、最新の月まで抜けが無い。
--    毎月、受理地別は全国と47都道府県、就業地別は47都道府県がそろう（実数・季節調整値とも）
-- 2. 受理地別の実数は、47都道府県の和が全国に一致する（求人数・求職者数）。1972年までの全国は沖縄県を含まない
-- 3. 受理地別の実数の求人倍率は、求人数 ÷ 求職者数に一致する。原典は小数第2位まで丸めるので 0.01 まで許す。
--    就業地別は、就業地別の求人数を受理地別の求職者数で割った値に一致する
-- 4. 年の平均は、その年の12か月の実数の平均に一致する（受理地別の有効求人数）。原典は人単位に丸めるので 1 まで許す

WITH m AS (
    SELECT * FROM {{ ref('labor_market_monthly') }}
),

span AS (
    SELECT basis, seasonally_adjusted,
        min(year * 100 + month) AS first_ym,
        count(DISTINCT year * 12 + month) AS n,
        max(year * 12 + month) - min(year * 12 + month) + 1 AS expected
    FROM m GROUP BY ALL
),

areas AS (
    SELECT basis, seasonally_adjusted, year, month, count(*) AS n
    FROM m GROUP BY ALL
),

totals AS (
    SELECT year, month,
        sum(active_job_openings) FILTER (WHERE area <> '00000' AND (year >= 1973 OR area <> '47000')) AS openings_sum,
        max(active_job_openings) FILTER (WHERE area = '00000') AS openings_total,
        sum(new_applications) FILTER (WHERE area <> '00000' AND (year >= 1973 OR area <> '47000')) AS applications_sum,
        max(new_applications) FILTER (WHERE area = '00000') AS applications_total
    FROM m WHERE basis = '受理地' AND NOT seasonally_adjusted
    GROUP BY ALL
),

ratios AS (
    SELECT w.basis, w.year, w.month, w.area,
        w.active_openings_ratio AS ratio,
        w.active_job_openings / a.active_applicants AS computed
    FROM m w
    JOIN m a ON a.basis = '受理地' AND a.seasonally_adjusted = w.seasonally_adjusted
        AND a.year = w.year AND a.month = w.month AND a.area = w.area
    WHERE NOT w.seasonally_adjusted
),

annual AS (
    SELECT y.year, y.area, y.active_job_openings AS annual, avg(m.active_job_openings) AS monthly_avg
    FROM {{ ref('labor_market_annual') }} y
    JOIN m ON m.basis = y.basis AND NOT m.seasonally_adjusted AND m.year = y.year AND m.area = y.area
    WHERE y.period_type = 'calendar_year' AND y.basis = '受理地'
    GROUP BY ALL
    HAVING count(*) = 12
)

SELECT 'span ' || basis || ' ' || seasonally_adjusted AS check_name, n || ' from ' || first_ym AS actual,
    expected || ' from ' || CASE basis WHEN '受理地' THEN '196301' ELSE '200502' END AS expected
FROM span
WHERE n <> expected OR first_ym <> CASE basis WHEN '受理地' THEN 196301 ELSE 200502 END

UNION ALL
SELECT 'areas ' || basis || ' ' || seasonally_adjusted || ' ' || year || '-' || month, n::VARCHAR,
    CASE basis WHEN '受理地' THEN '48' ELSE '47' END
FROM areas WHERE n <> CASE basis WHEN '受理地' THEN 48 ELSE 47 END

UNION ALL
SELECT 'openings total ' || year || '-' || month, openings_sum::VARCHAR, openings_total::VARCHAR
FROM totals WHERE openings_sum IS DISTINCT FROM openings_total

UNION ALL
SELECT 'applications total ' || year || '-' || month, applications_sum::VARCHAR, applications_total::VARCHAR
FROM totals WHERE applications_sum IS DISTINCT FROM applications_total

UNION ALL
SELECT 'ratio ' || basis || ' ' || year || '-' || month || ' ' || area, ratio::VARCHAR, round(computed, 2)::VARCHAR
FROM ratios WHERE NOT coalesce(abs(ratio - computed) <= 0.01, false)

UNION ALL
SELECT 'annual ' || year || ' ' || area, annual::VARCHAR, monthly_avg::VARCHAR
FROM annual WHERE abs(annual - monthly_avg) > 1
