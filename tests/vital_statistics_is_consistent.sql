-- 人口動態統計 (vital_statistics) の4表の整合を検証する。結果が0行ならテスト成功。
--
-- 1. 地域の段が全部に付き、政令指定都市の合計行が標準地域コードに当たっている
--    (原典は独自のコード 01010 などで持つので、code.municipality に名前で当てている)
-- 2. 年 × 地域ごとにセルが欠けずにそろっている。「-」を 0 に読み替えているので、
--    セルが欠けた行も 0 になって紛れる。欠けを先に見る
-- 3. 都道府県の値が、市区町村 (政令指定都市は合計行か区のどちらか) の合計に一致する
-- 4. 母の年齢別の出生数の合計が vital_events の出生数に、年齢別・死因別の死亡数の
--    合計 (死因は総数 Se00) が vital_events の死亡数に一致する
-- 5. 2015年から最新年まで年が連続し、最新年が 2024 年より前に下がっていない
-- 6. 地域が stg_vital_statistics_area に1回だけ出る。4表の地域を名前・階層ごと UNION して
--    いるので、表によって名前か階層が違うと同じ area が2行になり、結合で行が倍になる
--    (vital_events の区は 3・4 の検査に入らないので、倍になっても気付けない)
-- 7. 男女の和が総数に一致する (births_by_mother_age・deaths_by_age の説明に書いてある)、
--    全国が都道府県・外国・不詳の和に一致する (死亡の2表。出生の表は全国の行を持たない)
--
-- 元表は手元でだけ取り込む (load_local.py vital_statistics)。元表が無いカタログ (CI で
-- まだ公開していないとき) では 0 行の表になるので検査しない。

{% if local_source_loaded('vital_statistics_summary') %}
WITH area AS (
    SELECT * FROM {{ ref('stg_vital_statistics_area') }}
),

ev AS (
    SELECT * FROM {{ ref('vital_events') }}
),

-- 都道府県ごとに、市区町村の合計と都道府県の行を並べる。vital_events は政令指定都市の
-- 合計行を持つので区は混ぜない。ほかの表は合計行を持たないので区を足す
pref_check AS (
    SELECT 'vital_events' AS t, year, prefecture_code,
        SUM(births) FILTER (WHERE area_kind = 'prefecture') AS pref,
        SUM(births) FILTER (WHERE area_kind IN ('municipality', 'designated_city')) AS parts
    FROM ev GROUP BY ALL
    UNION ALL
    SELECT 'vital_events deaths', year, prefecture_code,
        SUM(deaths) FILTER (WHERE area_kind = 'prefecture'),
        SUM(deaths) FILTER (WHERE area_kind IN ('municipality', 'designated_city'))
    FROM ev GROUP BY ALL
    UNION ALL
    SELECT 'births_by_mother_age', year, prefecture_code,
        SUM(births) FILTER (WHERE area_kind = 'prefecture'),
        SUM(births) FILTER (WHERE area_kind IN ('municipality', 'ward'))
    FROM {{ ref('births_by_mother_age') }} GROUP BY ALL
    UNION ALL
    SELECT 'deaths_by_age', year, prefecture_code,
        SUM(deaths) FILTER (WHERE area_kind = 'prefecture'),
        SUM(deaths) FILTER (WHERE area_kind IN ('municipality', 'ward'))
    FROM {{ ref('deaths_by_age') }} WHERE prefecture_code IS NOT NULL GROUP BY ALL
    UNION ALL
    SELECT 'deaths_by_cause', year, prefecture_code,
        SUM(deaths) FILTER (WHERE area_kind = 'prefecture'),
        SUM(deaths) FILTER (WHERE area_kind IN ('municipality', 'ward'))
    FROM {{ ref('deaths_by_cause') }}
    WHERE prefecture_code IS NOT NULL AND cause_code = 'Se00' GROUP BY ALL
),

totals AS (
    SELECT year, area_code, area_kind, 'births_by_mother_age' AS t, SUM(births) AS v
    FROM {{ ref('births_by_mother_age') }} GROUP BY ALL
    UNION ALL
    SELECT year, area_code, area_kind, 'deaths_by_age', SUM(deaths)
    FROM {{ ref('deaths_by_age') }} GROUP BY ALL
    UNION ALL
    SELECT year, area_code, area_kind, 'deaths_by_cause', SUM(deaths)
    FROM {{ ref('deaths_by_cause') }} WHERE cause_code = 'Se00' GROUP BY ALL
),

nationwide_check AS (
    SELECT 'deaths_by_age' AS t, year,
        SUM(deaths) FILTER (WHERE area_kind = 'nationwide') AS nationwide,
        SUM(deaths) FILTER (WHERE area_kind IN ('prefecture', 'foreign', 'unknown')) AS parts
    FROM {{ ref('deaths_by_age') }} GROUP BY ALL
    UNION ALL
    SELECT 'deaths_by_cause', year,
        SUM(deaths) FILTER (WHERE area_kind = 'nationwide'),
        SUM(deaths) FILTER (WHERE area_kind IN ('prefecture', 'foreign', 'unknown'))
    FROM {{ ref('deaths_by_cause') }} WHERE cause_code = 'Se00' GROUP BY ALL
),

years AS (
    SELECT 'vital_events' AS t, MIN(year) AS first_year, MAX(year) AS last_year,
        COUNT(DISTINCT year) AS n FROM ev
    UNION ALL
    SELECT 'births_by_mother_age', MIN(year), MAX(year), COUNT(DISTINCT year)
    FROM {{ ref('births_by_mother_age') }}
    UNION ALL
    SELECT 'deaths_by_age', MIN(year), MAX(year), COUNT(DISTINCT year)
    FROM {{ ref('deaths_by_age') }}
    UNION ALL
    SELECT 'deaths_by_cause', MIN(year), MAX(year), COUNT(DISTINCT year)
    FROM {{ ref('deaths_by_cause') }}
)

SELECT 'area_kind or area_code is null' AS failure, area AS detail
FROM area WHERE area_kind IS NULL OR area_code IS NULL
UNION ALL
SELECT 'area appears more than once', area
FROM area GROUP BY area HAVING COUNT(*) > 1
UNION ALL
SELECT 'summary cells missing', year || ' ' || area_code
FROM {{ ref('stg_vital_statistics_summary') }} WHERE cells <> 12
UNION ALL
SELECT 'births_mother_age cells missing', year || ' ' || area_code || ' ' || mother_age_code
FROM {{ ref('stg_vital_statistics_births_mother_age') }} WHERE cells <> 3
UNION ALL
SELECT 'deaths_age cells missing', year || ' ' || area_code || ' ' || age_code
FROM {{ ref('stg_vital_statistics_deaths_age') }} WHERE cells <> 3
UNION ALL
SELECT 'deaths_cause cells missing', year || ' ' || area_code || ' ' || cause_code
FROM {{ ref('stg_vital_statistics_deaths_cause') }} WHERE cells <> 3
UNION ALL
SELECT 'prefecture != sum of parts: ' || t, year || ' ' || prefecture_code || ' ' || pref || ' / ' || parts
FROM pref_check WHERE pref IS DISTINCT FROM parts
UNION ALL
SELECT 'total does not match vital_events: ' || t.t, t.year || ' ' || t.area_code || ' ' || t.v || ' / ' || e.births
FROM totals AS t
INNER JOIN ev AS e USING (year, area_code)
WHERE t.t = 'births_by_mother_age' AND t.v <> e.births
UNION ALL
SELECT 'total does not match vital_events: ' || t.t, t.year || ' ' || t.area_code || ' ' || t.v || ' / ' || e.deaths
FROM totals AS t
INNER JOIN ev AS e USING (year, area_code)
WHERE t.t IN ('deaths_by_age', 'deaths_by_cause') AND t.v <> e.deaths
UNION ALL
SELECT 'male + female != total: births_by_mother_age', year || ' ' || area_code || ' ' || mother_age_code
FROM {{ ref('births_by_mother_age') }} WHERE births <> births_male + births_female
UNION ALL
SELECT 'male + female != total: deaths_by_age', year || ' ' || area_code || ' ' || age_code
FROM {{ ref('deaths_by_age') }} WHERE deaths <> deaths_male + deaths_female
UNION ALL
SELECT 'nationwide != prefecture + foreign + unknown: ' || t, year || ' ' || nationwide || ' / ' || parts
FROM nationwide_check WHERE nationwide IS DISTINCT FROM parts
UNION ALL
SELECT 'years are not continuous: ' || t, first_year || '-' || last_year || ' ' || n
FROM years WHERE first_year IS DISTINCT FROM 2015 OR COALESCE(last_year, 0) < 2024
    OR n <> last_year - first_year + 1
{% else %}
SELECT NULL AS failure, NULL AS detail WHERE FALSE
{% endif %}
