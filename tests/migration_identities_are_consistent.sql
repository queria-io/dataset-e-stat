-- municipality_migration で、地域階層と区分の恒等式が成り立つことを検証する。
-- 結果が0行ならテスト成功。
--
-- この表は全国・都道府県・市区町村・区のほかに、市部／郡部・郡・振興局・支庁という
-- 集計行が同じ列に縦に並ぶ。階層は area_level にしか出ておらず、それは e-Stat の
-- メタ情報の level と親コードから導いている。上流が level の振り方を変えると、
-- 行数も値も変わらないまま「合計に使える行」の集合だけがずれる。恒等式で落とす。
--
-- 恒等式の両辺は COALESCE(…, 0) で突き合わせる。片側だけ 0 に寄せると、区分のコードが
-- 丸ごと変わって SUM が 0 行 = NULL を返したときに比較そのものが NULL になり、テストが
-- 黙って通ってしまう。内訳が丸ごと消える壊れ方は行数の側で見る。
--
-- 原典の欠測値（NOTE で Null = 欠測値）があり、転出者数が入らない市区町村がある
-- （矢祭町 2010〜2014年・国立市 2010〜2011年）。転入超過数はその翌年まで入らない
-- （矢祭町 2015年・国立市 2012年）。都道府県と全国の値もその分を欠いたまま積まれて
-- いるので、和の恒等式はそのままで成り立つ。
--
-- 郡・振興局・支庁と市部／郡部の集計行は2024年までしか無い。2025年は全国・都道府県・
-- 市区町村・区の行だけなので、集計行がある年に絞って見る。
--
-- 政令指定都市に移行した年だけは、市の値が通年で区の値が4月以降になるため、区の和が
-- 市に届かない（相模原市2010年・熊本市2012年）。原典どおりの姿なので明示的に除く。
-- ここを「差が小さければ通す」にすると、区の行が丸ごと落ちる壊れ方を拾えなくなる。

{% set area_levels = [
    'national', 'prefecture', 'municipality', 'ward', 'county', 'urban_rural_part'
] %}

WITH by_sex AS (
    SELECT area, year, nationality_code,
        COUNT(*) FILTER (WHERE sex_code IN ('1', '2')) AS parts,
        MAX(inflow) FILTER (WHERE sex_code = '0') AS in_total,
        SUM(inflow) FILTER (WHERE sex_code IN ('1', '2')) AS in_parts,
        MAX(outflow) FILTER (WHERE sex_code = '0') AS out_total,
        SUM(outflow) FILTER (WHERE sex_code IN ('1', '2')) AS out_parts
    FROM {{ ref('municipality_migration') }}
    GROUP BY area, year, nationality_code
),

by_nationality AS (
    SELECT area, year, sex_code,
        COUNT(*) FILTER (WHERE nationality_code IN ('61000', '62000')) AS parts,
        MAX(inflow) FILTER (WHERE nationality_code = '60000') AS in_total,
        SUM(inflow) FILTER (WHERE nationality_code IN ('61000', '62000')) AS in_parts,
        MAX(outflow) FILTER (WHERE nationality_code = '60000') AS out_total,
        SUM(outflow) FILTER (WHERE nationality_code IN ('61000', '62000')) AS out_parts
    FROM {{ ref('municipality_migration') }}
    GROUP BY area, year, sex_code
),

-- 町村の親は郡・振興局・支庁で都道府県ではないので、市区町村の和は親コードではなく
-- コードの上2桁でまとめる。
municipality_sum AS (
    SELECT SUBSTR(area, 1, 2) || '000' AS pref, year, sex_code, nationality_code,
        SUM(inflow) AS in_sum, SUM(outflow) AS out_sum
    FROM {{ ref('municipality_migration') }}
    WHERE area_level = 'municipality'
    GROUP BY 1, year, sex_code, nationality_code
),

-- 都道府県側から外側結合する。内部結合にすると、ある都道府県の市区町村行が丸ごと
-- 消えたときにグループそのものが生まれず、0行 = 合格を返して素通りする。
by_prefecture AS (
    SELECT p.area, p.year, p.sex_code, p.nationality_code,
        p.inflow AS in_total, p.outflow AS out_total,
        m.in_sum, m.out_sum
    FROM {{ ref('municipality_migration') }} p
    LEFT JOIN municipality_sum m
        ON m.pref = p.area AND m.year = p.year
        AND m.sex_code = p.sex_code AND m.nationality_code = p.nationality_code
    WHERE p.area_level = 'prefecture'
),

prefecture_sum AS (
    SELECT year, sex_code, nationality_code,
        SUM(inflow) AS in_sum, SUM(outflow) AS out_sum
    FROM {{ ref('municipality_migration') }}
    WHERE area_level = 'prefecture'
    GROUP BY year, sex_code, nationality_code
),

by_national AS (
    SELECT n.area, n.year, n.sex_code, n.nationality_code,
        n.inflow AS in_total, n.outflow AS out_total,
        p.in_sum, p.out_sum
    FROM {{ ref('municipality_migration') }} n
    LEFT JOIN prefecture_sum p
        ON p.year = n.year AND p.sex_code = n.sex_code
        AND p.nationality_code = n.nationality_code
    WHERE n.area_level = 'national'
),

child_sum AS (
    SELECT parent_area, area_level, year, sex_code, nationality_code,
        SUM(inflow) AS in_sum, SUM(outflow) AS out_sum
    FROM {{ ref('municipality_migration') }}
    WHERE area_level IN ('ward', 'municipality')
    GROUP BY parent_area, area_level, year, sex_code, nationality_code
),

by_designated_city AS (
    SELECT c.area, c.area_name, c.year, c.sex_code, c.nationality_code,
        c.inflow AS in_total, c.outflow AS out_total,
        w.in_sum, w.out_sum
    FROM {{ ref('municipality_migration') }} c
    JOIN child_sum w
        ON w.parent_area = c.area AND w.area_level = 'ward' AND w.year = c.year
        AND w.sex_code = c.sex_code AND w.nationality_code = c.nationality_code
    WHERE c.area_level = 'municipality'
        AND NOT (c.area = '14150' AND c.year = 2010)
        AND NOT (c.area = '43100' AND c.year = 2012)
),

by_county AS (
    SELECT c.area, c.area_name, c.year, c.sex_code, c.nationality_code,
        c.inflow AS in_total, c.outflow AS out_total,
        t.in_sum, t.out_sum
    FROM {{ ref('municipality_migration') }} c
    JOIN child_sum t
        ON t.parent_area = c.area AND t.area_level = 'municipality' AND t.year = c.year
        AND t.sex_code = c.sex_code AND t.nationality_code = c.nationality_code
    WHERE c.area_level = 'county'
),

part_sum AS (
    SELECT SUBSTR(area, 1, 2) || '000' AS pref, year, sex_code, nationality_code,
        SUM(inflow) AS in_sum, SUM(outflow) AS out_sum, COUNT(*) AS n
    FROM {{ ref('municipality_migration') }}
    WHERE area_level = 'urban_rural_part'
    GROUP BY 1, year, sex_code, nationality_code
),

-- 恒等式はどれも「対象0行 = 合格」を返せる。取得の条件や表章コードが変わって表が空に
-- なる壊れ方は、収録年と地域数の側で見る。
expected_years AS (
    SELECT UNNEST(RANGE(2010, (SELECT MAX(year) FROM {{ ref('municipality_migration') }}) + 1))
        AS year
),

-- 区分の顔ぶれも年ごとに固定する。stg は年代で並びの違う分類軸を読み替えているので、
-- 取り違えると性別コードに国籍のコードが、国籍コードに性別のコードが入る。それだけなら
-- 一意性も和の恒等式も通ってしまい、総数と内訳を突き合わせる検査は総数の行が見つからずに
-- 「対象0行 = 合格」を返す。
sex_by_year AS (
    SELECT year, LIST_SORT(ARRAY_AGG(DISTINCT sex_code)) AS codes
    FROM {{ ref('municipality_migration') }}
    GROUP BY year
),

nationality_by_year AS (
    SELECT year, LIST_SORT(ARRAY_AGG(DISTINCT nationality_code)) AS codes
    FROM {{ ref('municipality_migration') }}
    GROUP BY year
),

-- 測定項目が丸ごと NULL になる壊れ方（表章コードの読み替えが外れると
-- WHERE measure IS NOT NULL が痕跡なく落とす）は、恒等式では捉えられない。
-- 両辺が 0 になって通る。全期間そろう系列で NOT NULL を見る。
national_series AS (
    SELECT e.year,
        COUNT(m.area) AS rows,
        COUNT(*) FILTER (
            WHERE m.inflow IS NULL OR m.outflow IS NULL OR m.net_inflow IS NULL
        ) AS incomplete_rows
    FROM expected_years e
    LEFT JOIN {{ ref('municipality_migration') }} m
        ON m.year = e.year AND m.area = '00000'
        AND m.sex_code = '0' AND m.nationality_code = '61000'
    GROUP BY e.year
),

area_counts AS (
    SELECT year,
        COUNT(DISTINCT area) FILTER (WHERE area_level = 'national') AS national_areas,
        COUNT(DISTINCT area) FILTER (WHERE area_level = 'prefecture') AS prefecture_areas
    FROM {{ ref('municipality_migration') }}
    GROUP BY year
),

by_part AS (
    SELECT p.area, p.year, p.sex_code, p.nationality_code,
        p.inflow AS in_total, p.outflow AS out_total,
        t.in_sum, t.out_sum, t.n
    FROM {{ ref('municipality_migration') }} p
    JOIN part_sum t
        ON t.pref = p.area AND t.year = p.year
        AND t.sex_code = p.sex_code AND t.nationality_code = p.nationality_code
    WHERE p.area_level IN ('national', 'prefecture')
)

SELECT '行が無い、または収録が2010年から始まっていない' AS violation,
    COALESCE(CAST(min_year AS VARCHAR), 'empty') AS detail
FROM (
    SELECT COUNT(*) AS rows, MIN(year) AS min_year
    FROM {{ ref('municipality_migration') }}
)
WHERE rows = 0 OR min_year <> 2010

UNION ALL

SELECT '収録されていない年がある', CAST(e.year AS VARCHAR)
FROM expected_years e
LEFT JOIN (SELECT DISTINCT year FROM {{ ref('municipality_migration') }}) y USING (year)
WHERE y.year IS NULL

UNION ALL

SELECT '性別コードの顔ぶれが違う',
    CAST(year AS VARCHAR) || ' ' || ARRAY_TO_STRING(codes, ',')
FROM sex_by_year
WHERE codes <> LIST_SORT(['0', '1', '2']::VARCHAR[])

UNION ALL

SELECT '国籍コードの顔ぶれが違う',
    CAST(year AS VARCHAR) || ' ' || ARRAY_TO_STRING(codes, ',')
FROM nationality_by_year
WHERE codes <> CASE
    WHEN year >= 2020 THEN LIST_SORT(['60000', '61000', '62000']::VARCHAR[])
    WHEN year >= 2018 THEN LIST_SORT(['60000', '61000']::VARCHAR[])
    ELSE ['61000']::VARCHAR[]
END

UNION ALL

SELECT '全国・総数・日本人移動者の行が欠けている、または値が NULL',
    CAST(year AS VARCHAR) || ' 行' || CAST(rows AS VARCHAR)
        || ' 欠け' || CAST(incomplete_rows AS VARCHAR)
FROM national_series
WHERE rows <> 1 OR incomplete_rows > 0

UNION ALL

SELECT '全国または都道府県の行が揃っていない',
    CAST(year AS VARCHAR) || ' 全国' || CAST(national_areas AS VARCHAR)
        || ' 都道府県' || CAST(prefecture_areas AS VARCHAR)
FROM area_counts
WHERE national_areas <> 1 OR prefecture_areas <> 47

UNION ALL

SELECT 'area_level が付いていない', area || ' ' || CAST(year AS VARCHAR)
FROM {{ ref('municipality_migration') }}
WHERE area_level IS NULL

UNION ALL

SELECT 'area_level の顔ぶれが違う', ARRAY_TO_STRING(levels, ',')
FROM (
    SELECT LIST_SORT(ARRAY_AGG(DISTINCT area_level)) AS levels
    FROM {{ ref('municipality_migration') }}
)
WHERE levels <> LIST_SORT({{ area_levels }}::VARCHAR[])

UNION ALL

SELECT '地域×年×性別×国籍が一意でない',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code || ' ' || nationality_code
FROM {{ ref('municipality_migration') }}
GROUP BY area, year, sex_code, nationality_code
HAVING COUNT(*) > 1

UNION ALL

SELECT '転入超過数 <> 転入者数 - 転出者数',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code || ' ' || nationality_code
FROM {{ ref('municipality_migration') }}
WHERE inflow IS NOT NULL AND outflow IS NOT NULL AND net_inflow IS NOT NULL
    AND net_inflow <> inflow - outflow

UNION ALL

SELECT '性別の総数 <> 男 + 女（転入者数）',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || nationality_code
FROM by_sex
WHERE parts = 2 AND COALESCE(in_total, 0) <> COALESCE(in_parts, 0)

UNION ALL

SELECT '性別の総数 <> 男 + 女（転出者数）',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || nationality_code
FROM by_sex
WHERE parts = 2 AND COALESCE(out_total, 0) <> COALESCE(out_parts, 0)

UNION ALL

SELECT '移動者 <> 日本人移動者 + 外国人移動者（転入者数）',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code
FROM by_nationality
WHERE parts = 2 AND COALESCE(in_total, 0) <> COALESCE(in_parts, 0)

UNION ALL

SELECT '移動者 <> 日本人移動者 + 外国人移動者（転出者数）',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code
FROM by_nationality
WHERE parts = 2 AND COALESCE(out_total, 0) <> COALESCE(out_parts, 0)

UNION ALL

SELECT '都道府県に対応する市区町村の行が無い',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code || ' ' || nationality_code
FROM by_prefecture WHERE in_sum IS NULL

UNION ALL

SELECT '都道府県 <> 市区町村の和',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code || ' ' || nationality_code
FROM by_prefecture
WHERE COALESCE(in_total, 0) <> COALESCE(in_sum, 0)
    OR COALESCE(out_total, 0) <> COALESCE(out_sum, 0)

UNION ALL

SELECT '全国 <> 都道府県の和',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code || ' ' || nationality_code
FROM by_national
WHERE COALESCE(in_total, 0) <> COALESCE(in_sum, 0)
    OR COALESCE(out_total, 0) <> COALESCE(out_sum, 0)

UNION ALL

SELECT '政令指定都市 <> 区の和',
    area || ' ' || area_name || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code
FROM by_designated_city
WHERE COALESCE(in_total, 0) <> COALESCE(in_sum, 0)
    OR COALESCE(out_total, 0) <> COALESCE(out_sum, 0)

UNION ALL

SELECT '郡・振興局・支庁 <> 町村の和',
    area || ' ' || area_name || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code
FROM by_county
WHERE COALESCE(in_total, 0) <> COALESCE(in_sum, 0)
    OR COALESCE(out_total, 0) <> COALESCE(out_sum, 0)

UNION ALL

SELECT '都道府県 <> 市部 + 郡部',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code || ' ' || nationality_code
FROM by_part
WHERE n <> 2
    OR COALESCE(in_total, 0) <> COALESCE(in_sum, 0)
    OR COALESCE(out_total, 0) <> COALESCE(out_sum, 0)
