-- crop.vegetable_production の整合を検証する。結果が0行ならテスト成功。
--
-- 地域はパイプラインが名前から当てている。年代で地域コードが 08000 → 1020 と変わり、
-- N0001 が平成16年産では関東農政局、平成26年産では全国を指すので、コードでつなぐと
-- 別の地域が黙って混ざる。当て違いを次の形で捕まえる。
-- - 全国の値は、同じ品目・作型の都道府県の値の最大より小さくならない
-- - キャベツは毎年、全国と群馬・愛知（主産県）の収穫量がそろう
--
-- 作型の読み違い（表題の末尾の揺れ）は、作型の値の集合と、全国のキャベツで
-- 計 = 春 + 夏秋 + 冬（公表の丸めで 1% 以内）が成り立つことで見る。
--
-- 突き合わせだけだと年産が丸ごと消えたときに 0 行で成功してしまうので、
-- 2003年産から最新年産まで年産が連続することも見る。

WITH v AS (
    SELECT * FROM {{ ref('vegetable_production') }}
),

prefecture_max AS (
    SELECT year, crop, season, subset, MAX(harvest_t) AS max_harvest
    FROM v
    WHERE area <> '00000'
    GROUP BY ALL
),

cabbage AS (
    SELECT
        year,
        MAX(harvest_t) FILTER (WHERE season = '計') AS total,
        SUM(harvest_t) FILTER (WHERE season IN ('春', '夏秋', '冬')) AS seasons
    FROM v
    WHERE crop = 'キャベツ' AND area = '00000' AND subset IS NULL
    GROUP BY ALL
),

cabbage_main AS (
    SELECT year, COUNT(harvest_t) AS n
    FROM v
    WHERE crop = 'キャベツ' AND season = '計' AND subset IS NULL
        AND area IN ('00000', '10000', '23000')
    GROUP BY ALL
),

years AS (
    SELECT MIN(year) AS first_year, MAX(year) AS last_year, COUNT(DISTINCT year) AS n
    FROM v
)

SELECT 'duplicate_key' AS check_name, year, area, COUNT(*) AS difference
FROM v
GROUP BY year, crop, season, subset, area
HAVING COUNT(*) > 1

UNION ALL
SELECT 'national_below_prefecture', v.year, v.crop, NULL
FROM v
JOIN prefecture_max p USING (year, crop, season, subset)
WHERE v.area = '00000' AND v.harvest_t < p.max_harvest

UNION ALL
SELECT 'unknown_season', year, season, NULL
FROM v
WHERE season NOT IN ('計', '春', '夏', '秋', '冬', '春夏', '夏秋', '秋冬', '冬春',
    '春植え', '秋植え', 'その他', '温室')

UNION ALL
SELECT 'cabbage_seasons_do_not_sum', year, NULL, total - seasons
FROM cabbage
WHERE total IS NULL OR seasons IS NULL OR ABS(total - seasons) > total * 0.01

UNION ALL
SELECT 'cabbage_main_missing', year, NULL, 3 - n
FROM cabbage_main
WHERE n <> 3

UNION ALL
SELECT 'negative_value', year, area, NULL
FROM v
WHERE planted_area_ha < 0 OR yield_kg_per_10a < 0 OR harvest_t < 0 OR shipment_t < 0

UNION ALL
SELECT 'year_gap', last_year, NULL, n - (last_year - 2003 + 1)
FROM years
WHERE first_year <> 2003 OR n <> last_year - 2003 + 1
