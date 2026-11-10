-- エネルギー消費統計調査の都道府県別の表 (energy_consumption.prefecture_industry・
-- prefecture_energy_type) の整合を検証する。結果が0行ならテスト成功。
--
-- 計と内訳が同じ列に並ぶ表なので、次の足し算がどの年度でもそろう。値は実数なので
-- 0.01 TJ の幅で比べる (原典の小数の丸めの差は 1e-9 TJ ほど)。列や行を取り違えると
-- どれかが合わなくなる。
-- 1. 47都道府県の合計 = 全国 (業種・種別ごと)
-- 2. 同じ親の行の合計 = 親の行 (業種・種別ごと、都道府県ごと)
-- 3. 業種計 = エネルギー種別の合計 (2表で同じ量を別の切り口で分けている)
-- 4. 都道府県名がすべて標準地域コードに当たる
--
-- 突き合わせだけだと年度が丸ごと消えたときに 0 行で成功してしまうので、2009年度から
-- 最新年度まで年度が連続し、各年度に全国+47都道府県 × 46業種・37種別がそろうことも見る。

WITH ind AS (
    SELECT * FROM {{ ref('prefecture_industry') }}
),

en AS (
    SELECT * FROM {{ ref('prefecture_energy_type') }}
),

prefecture_sums AS (
    SELECT 'industry' AS tbl, fiscal_year, industry_code AS item,
        sum(energy_tj) FILTER (WHERE area <> '00000') AS prefectures,
        max(energy_tj) FILTER (WHERE area = '00000') AS nationwide
    FROM ind GROUP BY ALL
    UNION ALL
    SELECT 'energy_type', fiscal_year, energy_type,
        sum(energy_tj) FILTER (WHERE area <> '00000'),
        max(energy_tj) FILTER (WHERE area = '00000')
    FROM en GROUP BY ALL
),

child_sums AS (
    SELECT 'industry' AS tbl, c.fiscal_year, c.area, c.parent_industry_code AS item,
        sum(c.energy_tj) AS children, max(p.energy_tj) AS parent
    FROM ind c
    LEFT JOIN ind p
        ON p.fiscal_year = c.fiscal_year AND p.area = c.area AND p.industry_code = c.parent_industry_code
    WHERE c.parent_industry_code IS NOT NULL
    GROUP BY ALL
    UNION ALL
    SELECT 'energy_type', c.fiscal_year, c.area, c.parent_energy_type,
        sum(c.energy_tj), max(p.energy_tj)
    FROM en c
    LEFT JOIN en p
        ON p.fiscal_year = c.fiscal_year AND p.area = c.area AND p.energy_type = c.parent_energy_type
    WHERE c.parent_energy_type IS NOT NULL
    GROUP BY ALL
),

counts AS (
    SELECT 'industry' AS tbl, fiscal_year, count(DISTINCT area) AS areas, count(DISTINCT industry_code) AS items, count(*) AS n
    FROM ind GROUP BY ALL
    UNION ALL
    SELECT 'energy_type', fiscal_year, count(DISTINCT area), count(DISTINCT energy_type), count(*)
    FROM en GROUP BY ALL
),

years AS (
    SELECT tbl, min(fiscal_year) AS first_year, max(fiscal_year) AS last_year, count(*) AS n
    FROM counts GROUP BY ALL
)

SELECT 'prefectures do not sum to nationwide' AS problem, tbl, fiscal_year, item AS detail
FROM prefecture_sums
WHERE nationwide IS NULL OR abs(prefectures - nationwide) > 0.01

UNION ALL

SELECT 'children do not sum to parent', tbl, fiscal_year, area || ' ' || item
FROM child_sums
WHERE parent IS NULL OR abs(children - parent) > 0.01

UNION ALL

SELECT 'industry total differs from energy type total', 'both', i.fiscal_year, i.area
FROM ind i
LEFT JOIN en e
    ON e.fiscal_year = i.fiscal_year AND e.area = i.area AND e.energy_type = '合計'
WHERE i.industry_code = 'A~S' AND (e.energy_tj IS NULL OR abs(i.energy_tj - e.energy_tj) > 0.01)

UNION ALL

SELECT 'unmatched prefecture name', 'both', NULL, label
FROM {{ ref('stg_energy_consumption_prefecture') }}
WHERE area IS NULL OR area_name IS NULL

UNION ALL

SELECT 'incomplete year', tbl, fiscal_year, areas::VARCHAR || ' areas, ' || items::VARCHAR || ' items'
FROM counts
WHERE areas <> 48 OR items <> CASE tbl WHEN 'industry' THEN 46 ELSE 37 END OR n <> areas * items

UNION ALL

SELECT 'year gap', tbl, last_year, n::VARCHAR || ' years from ' || first_year::VARCHAR
FROM years
WHERE first_year <> 2009 OR n <> last_year - 2009 + 1
