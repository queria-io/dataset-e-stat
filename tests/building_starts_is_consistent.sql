-- building_starts の mart が、原典の構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 統計表は2019年までと2020年以降の2つで、stg で積んで表章を列に広げている。
-- 広げるときに (地域, 年, 用途) で MAX を取るので、mart の一意性は作りの上で必ず
-- 成り立ち、検査にならない。e-Stat 側が軸を足したときや、2つの表の年が重なった
-- ときは、畳む前の raw で (地域, 年, 用途, 表章) が2行以上になる。そちらを見る。
--
-- 地域の集計行（郡・振興局・支庁・特別区部）は stg で落としている。2020〜2023年の
-- 集計行は値が 0 で、2024年だけ子の合計と一致する。判定がずれて集計行が
-- municipality に入ると、市区町村の合計が全国より大きくなる。全国の値はこの表に
-- 無いので、区の合計=政令指定都市・用途の合計=計 の足し算と、area_level の値の
-- 種類で押さえる。
--
-- 着工の無い地域・年は行を持たない（年によって原典が 0 の行を載せたり載せなかったり
-- するのを、載せない側にそろえている）。計が 0 の行が出てきたら揃え方が崩れている。
--
-- 秘匿（原典の「＊」）はローダーの時点で NULL になる。工事費予定額は秘匿が多い
-- ので NOT NULL では見られないが、2019年までの計の非 NULL が9割を切るなら
-- 表記の変化で値が全部落ちている。床面積の秘匿は既知の1セル（2018年 新潟市北区
-- 教育，学習支援業用）だけで、増えたら値を見てから足す。
--
-- 地域コードは各年の時点のもので、合併で消えた市町村や浜松市の再編前の区は
-- 現行の code.municipality に無い。最新年のコードはすべて載るはずで、載らないと
-- 地域コードを鍵にした結合が黙って行を落とす。
--
-- 集計行の判定は e-Stat のメタ情報（level と親コード）で行っていて、コードの形
-- だけでは郡と町村を見分けられない（後志総合振興局 01390 の下に倶知安町 01400 が
-- ある）。code.municipality に載るコードは、そちらの area_kind と粒度を突き合わせる。

{% set known_null_floor_area = [('15101', 2018, '59')] %}

WITH raw_cells AS (
    SELECT area, time, cat01, tab FROM {{ ref('raw_building_starts_municipality_use') }}
    UNION ALL
    SELECT area, time, cat01, tab FROM {{ ref('raw_building_starts_municipality_use_pre2020') }}
),

mart AS (
    SELECT * FROM {{ ref('municipality_use') }}
),

expected_years AS (
    SELECT UNNEST(RANGE(2011, (SELECT MAX(year) FROM mart) + 1)) AS year
),

totals AS (
    SELECT area, area_level, parent_area, year, buildings, floor_area, construction_cost
    FROM mart
    WHERE use_code = '11'
),

use_sums AS (
    SELECT area, year,
        SUM(buildings) AS buildings,
        SUM(floor_area) AS floor_area,
        COUNT(*) - COUNT(floor_area) AS null_floor_area
    FROM mart
    WHERE use_code <> '11'
    GROUP BY area, year
),

ward_sums AS (
    SELECT parent_area AS area, year,
        SUM(buildings) AS buildings,
        SUM(floor_area) AS floor_area,
        COUNT(*) - COUNT(floor_area) AS null_floor_area
    FROM totals
    WHERE area_level = 'ward'
    GROUP BY parent_area, year
),

null_floor_area AS (
    SELECT area, year, use_code FROM mart WHERE floor_area IS NULL
),

known_null_floor_area AS (
    SELECT * FROM (VALUES
        {%- for area, year, use_code in known_null_floor_area %}
        ('{{ area }}', {{ year }}, '{{ use_code }}'){{ "," if not loop.last }}
        {%- endfor %}
    ) AS t(area, year, use_code)
),

-- EXCEPT は UNION ALL と同じ優先順位で左から結合するので、下の並びに直接
-- 書くとそれまでの検査結果ごと引かれる。CTE に閉じ込める。
unexpected_null_floor_area AS (
    SELECT * FROM null_floor_area EXCEPT ALL SELECT * FROM known_null_floor_area
),

level_mismatch AS (
    SELECT DISTINCT p.area, p.area_level, m.area_kind
    FROM mart p
    JOIN {{ ref('municipality') }} m ON m.area_code = p.area
    WHERE (p.area_level = 'municipality' AND NOT m.is_municipality)
        OR (p.area_level = 'ward' AND m.area_kind <> 'ward')
),

latest_unresolved_areas AS (
    SELECT DISTINCT p.area
    FROM mart p
    LEFT JOIN {{ ref('municipality') }} m ON m.area_code = p.area
    WHERE p.year = (SELECT MAX(year) FROM mart) AND m.area_code IS NULL
)

SELECT '行が無い、または収録が2011年から始まっていない' AS violation,
    COALESCE(CAST(min_year AS VARCHAR), 'empty') AS detail
FROM (SELECT COUNT(*) AS rows, MIN(year) AS min_year FROM mart)
WHERE rows = 0 OR min_year <> 2011

UNION ALL

SELECT '収録されていない年がある', CAST(e.year AS VARCHAR)
FROM expected_years e
LEFT JOIN (SELECT DISTINCT year FROM mart) y USING (year)
WHERE y.year IS NULL

UNION ALL

SELECT '原典の地域×年×用途×表章が一意でない',
    area || ' ' || time || ' ' || cat01 || ' ' || tab
FROM raw_cells
GROUP BY area, time, cat01, tab
HAVING COUNT(*) > 1

UNION ALL

SELECT '地域×年に用途の19区分がそろわない', area || ' ' || CAST(year AS VARCHAR)
FROM mart
GROUP BY area, year
HAVING COUNT(DISTINCT use_code) <> 19 OR COUNT(*) FILTER (WHERE use_code = '11') <> 1

UNION ALL

SELECT 'area_level が municipality / ward 以外', COALESCE(area_level, 'NULL')
FROM (SELECT DISTINCT area_level FROM mart)
WHERE area_level IS NULL OR area_level NOT IN ('municipality', 'ward')

UNION ALL

SELECT '地域コードが5桁でないか、都道府県・集計行のコード', area
FROM (SELECT DISTINCT area FROM mart)
WHERE NOT regexp_matches(area, '^[0-4][0-9][0-9]{3}$')
    OR area LIKE '%000' OR area = '13100'

UNION ALL

SELECT '都道府県が47そろわない年がある',
    CAST(year AS VARCHAR) || ' ' || CAST(COUNT(DISTINCT LEFT(area, 2)) AS VARCHAR)
FROM totals
WHERE area_level = 'municipality'
GROUP BY year
HAVING COUNT(DISTINCT LEFT(area, 2)) <> 47

UNION ALL

SELECT '計の建築物の数が 0 以下か NULL', area || ' ' || CAST(year AS VARCHAR)
FROM totals
WHERE buildings IS NULL OR buildings <= 0

UNION ALL

SELECT '建築物の数が NULL', area || ' ' || CAST(year AS VARCHAR) || ' ' || use_code
FROM mart
WHERE buildings IS NULL

UNION ALL

SELECT '負の値がある', area || ' ' || CAST(year AS VARCHAR) || ' ' || use_code
FROM mart
WHERE buildings < 0 OR floor_area < 0 OR construction_cost < 0

UNION ALL

SELECT '床面積の秘匿が既知の1セル以外にある',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || use_code
FROM unexpected_null_floor_area

UNION ALL

SELECT '用途の合計が計と一致しない', t.area || ' ' || CAST(t.year AS VARCHAR)
FROM totals t
JOIN use_sums u USING (area, year)
WHERE t.buildings <> u.buildings
    OR (u.null_floor_area = 0 AND t.floor_area <> u.floor_area)

UNION ALL

SELECT '区の合計が政令指定都市と一致しない', t.area || ' ' || CAST(t.year AS VARCHAR)
FROM totals t
JOIN ward_sums w USING (area, year)
WHERE t.buildings <> w.buildings
    OR (w.null_floor_area = 0 AND t.floor_area <> w.floor_area)

UNION ALL

SELECT '区の親が municipality の行に無い', w.area || ' ' || CAST(w.year AS VARCHAR)
FROM ward_sums w
LEFT JOIN totals t ON t.area = w.area AND t.year = w.year AND t.area_level = 'municipality'
WHERE t.area IS NULL

UNION ALL

SELECT '2020年以降に工事費予定額がある', CAST(year AS VARCHAR)
FROM mart
WHERE year >= 2020 AND construction_cost IS NOT NULL
GROUP BY year

UNION ALL

SELECT '2019年までの計の工事費予定額の非 NULL が9割を切っている',
    CAST(year AS VARCHAR) || ' ' || CAST(ROUND(100.0 * COUNT(construction_cost) / COUNT(*), 1) AS VARCHAR) || '%'
FROM totals
WHERE year < 2020
GROUP BY year
HAVING COUNT(construction_cost) * 10 < COUNT(*) * 9

UNION ALL

SELECT '最新年の地域コードが標準地域コードに無い', area
FROM latest_unresolved_areas

UNION ALL

SELECT '標準地域コードの階層区分と area_level が食い違う',
    area || ' ' || area_level || ' ' || area_kind
FROM level_mismatch
