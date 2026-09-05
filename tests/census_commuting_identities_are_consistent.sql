-- 従業地・通学地集計の 2 表で、総数と内訳の恒等式が成り立つことを検証する。
-- 結果が0行ならテスト成功。
--
-- どちらの表も総数・大区分・その内訳が同じ列に縦に並ぶ縦持ちで、階層は
-- location_level / is_reprint / destination_area_level にしか出ていない。原典のコードが
-- 振り直されたり階層の付け方が変わったりすると、行数も area_level も変わらないまま
-- 「合計に使える行」の集合だけがずれる。恒等式で落とす。
--
-- 恒等式は両辺を COALESCE(…, 0) で突き合わせる。片側だけ 0 に寄せると、内訳のコードが
-- 丸ごと変わって SUM が 0 行 = NULL を返したときに比較そのものが NULL になり、テストが
-- 黙って通ってしまう。区分の顔ぶれが変わる壊れ方は恒等式では捉えられない（総数も内訳も
-- 揃って別のコードに移れば両辺とも 0 になる）ので、区分のコードが原典どおり揃っている
-- ことも併せて見る。
--
-- 原典が「-」の区分は NULL で入っており、該当者がいないこと(0人)を表すので 0 とみなして
-- 足す。全国行の流出人口・流入人口は定義上存在せず NULL なので、昼間人口 = 夜間人口 に
-- なって恒等式は成り立つ。
--
-- 2 表をまたぐ恒等式も見る。census_commuting_flow は自宅外で従業・通学する人だけを
-- 数えており、その総数から従業地・通学地「不詳」を除いたものが
-- census_municipality_daytime_population の「自宅外の自市区町村で従業・通学」+
-- 「他市区町村で従業・通学」に一致する。ここがずれたら、どちらかの表で母集団の定義が
-- 変わっている。

{% set location_codes = [
    '0', '001', '002', '0021', '0022', '003', '0031', '0032', '0033', '0034',
    '004', '0R1', '1', '101', '1011', '1012', '1013', '102', '1R1'
] %}
{% set destination_levels = ['prefecture', 'total', 'unknown'] %}

WITH daytime AS (
    SELECT
        area,
        sex_code,
        LIST_SORT(ARRAY_AGG(DISTINCT location_code)) AS category_codes,
        COALESCE(MAX(value) FILTER (WHERE location_code = '0'), 0) AS nighttime,
        COALESCE(SUM(value) FILTER (
            WHERE location_level = 2
                AND population_base = 'nighttime'
                AND NOT is_reprint
        ), 0) AS nighttime_parts,
        COALESCE(MAX(value) FILTER (WHERE location_code = '002'), 0) AS own_municipality,
        COALESCE(SUM(value) FILTER (
            WHERE location_code IN ('0021', '0022')
        ), 0) AS own_municipality_parts,
        COALESCE(MAX(value) FILTER (WHERE location_code = '003'), 0) AS other_municipality,
        COALESCE(SUM(value) FILTER (
            WHERE location_code IN ('0031', '0032', '0033', '0034')
        ), 0) AS other_municipality_parts,
        COALESCE(MAX(value) FILTER (WHERE location_code = '101'), 0) AS from_other,
        COALESCE(SUM(value) FILTER (
            WHERE location_code IN ('1011', '1012', '1013')
        ), 0) AS from_other_parts,
        COALESCE(MAX(value) FILTER (WHERE location_code = '1'), 0) AS daytime,
        COALESCE(MAX(value) FILTER (WHERE location_code = '0R1'), 0) AS outflow,
        COALESCE(MAX(value) FILTER (WHERE location_code = '1R1'), 0) AS inflow
    FROM {{ ref('census_municipality_daytime_population') }}
    GROUP BY area, sex_code
),

-- 男 + 女 = 総数。男女の区分が入れ替わっても行数は変わらない。
daytime_by_sex AS (
    SELECT
        area,
        location_code AS category_code,
        COALESCE(MAX(value) FILTER (WHERE sex_code = '0'), 0) AS both_sexes,
        COALESCE(SUM(value) FILTER (WHERE sex_code IN ('1', '2')), 0) AS male_female
    FROM {{ ref('census_municipality_daytime_population') }}
    GROUP BY area, location_code
),

flow AS (
    SELECT
        area,
        sex_code,
        LIST_SORT(ARRAY_AGG(DISTINCT destination_area_level)) AS level_names,
        COALESCE(MAX(value) FILTER (WHERE destination_area_level = 'total'), 0) AS total,
        COALESCE(SUM(value) FILTER (WHERE destination_area_level <> 'total'), 0) AS total_parts,
        COALESCE(MAX(value) FILTER (WHERE destination_area = '99998'), 0) AS unknown_municipality,
        COALESCE(MAX(value) FILTER (WHERE destination_area = '99999'), 0) AS unknown_destination
    FROM {{ ref('census_commuting_flow') }}
    GROUP BY area, sex_code
),

flow_by_sex AS (
    SELECT
        area,
        destination_area AS category_code,
        COALESCE(MAX(value) FILTER (WHERE sex_code = '0'), 0) AS both_sexes,
        COALESCE(SUM(value) FILTER (WHERE sex_code IN ('1', '2')), 0) AS male_female
    FROM {{ ref('census_commuting_flow') }}
    GROUP BY area, destination_area
),

-- 常住地の粒度を揃えて足すと全国行に戻る。従業地・通学地ごとに見る。
flow_by_destination AS (
    SELECT
        destination_area,
        sex_code,
        COALESCE(MAX(value) FILTER (WHERE area_level = 'national'), 0) AS national,
        COALESCE(SUM(value) FILTER (WHERE area_level = 'prefecture'), 0) AS prefecture_sum,
        COALESCE(SUM(value) FILTER (
            WHERE area_level IN ('city', 'town_village')
        ), 0) AS municipality_sum
    FROM {{ ref('census_commuting_flow') }}
    GROUP BY destination_area, sex_code
),

-- 2 表の母集団の突き合わせ。
cross_table AS (
    SELECT
        f.area,
        f.sex_code,
        f.total - f.unknown_destination AS flow_known,
        d.commuters AS daytime_commuters,
        f.unknown_municipality AS flow_unknown_municipality,
        d.unknown_municipality AS daytime_unknown_municipality
    FROM flow f
    JOIN (
        SELECT
            area,
            sex_code,
            COALESCE(SUM(value) FILTER (
                WHERE location_code IN ('0022', '003')
            ), 0) AS commuters,
            COALESCE(MAX(value) FILTER (WHERE location_code = '0034'), 0) AS unknown_municipality
        FROM {{ ref('census_municipality_daytime_population') }}
        GROUP BY area, sex_code
    ) d USING (area, sex_code)
)

SELECT 'daytime: 常住地又は従業地・通学地の区分が原典と違う' AS violation, area, ARRAY_TO_STRING(category_codes, ',') AS code
FROM daytime
WHERE category_codes <> LIST_SORT({{ location_codes }}::VARCHAR[])
UNION ALL
SELECT 'daytime: 夜間人口 <> 大区分4つの和', area, sex_code
FROM daytime WHERE nighttime <> nighttime_parts
UNION ALL
SELECT 'daytime: 自市区町村で従業・通学 <> 内訳2区分の和', area, sex_code
FROM daytime WHERE own_municipality <> own_municipality_parts
UNION ALL
SELECT 'daytime: 他市区町村で従業・通学 <> 内訳4区分の和', area, sex_code
FROM daytime WHERE other_municipality <> other_municipality_parts
UNION ALL
SELECT 'daytime: うち他市区町村に常住 <> 内訳3区分の和', area, sex_code
FROM daytime WHERE from_other <> from_other_parts
UNION ALL
SELECT 'daytime: 昼間人口 <> 夜間人口 - 流出人口 + 流入人口', area, sex_code
FROM daytime WHERE daytime <> nighttime - outflow + inflow
UNION ALL
SELECT 'daytime: 総数 <> 男 + 女', area, category_code
FROM daytime_by_sex WHERE both_sexes <> male_female
UNION ALL
SELECT 'flow: 従業地・通学地の粒度が原典と違う', area, ARRAY_TO_STRING(level_names, ',')
FROM flow
WHERE level_names <> LIST_SORT({{ destination_levels }}::VARCHAR[])
UNION ALL
SELECT 'flow: 総数 <> 都道府県 + 不詳2区分の和', area, sex_code
FROM flow WHERE total <> total_parts
UNION ALL
SELECT 'flow: 総数 <> 男 + 女', area, category_code
FROM flow_by_sex WHERE both_sexes <> male_female
UNION ALL
SELECT 'flow: 全国 <> 都道府県の和', destination_area, sex_code
FROM flow_by_destination WHERE national <> prefecture_sum
UNION ALL
SELECT 'flow: 全国 <> 市 + 町村の和', destination_area, sex_code
FROM flow_by_destination WHERE national <> municipality_sum
UNION ALL
SELECT 'cross: flow の自宅外通勤・通学者 <> daytime の自宅外の自市区町村 + 他市区町村', area, sex_code
FROM cross_table WHERE flow_known <> daytime_commuters
UNION ALL
SELECT 'cross: flow の従業・通学市区町村「不詳・外国」 <> daytime の同区分', area, sex_code
FROM cross_table WHERE flow_unknown_municipality <> daytime_unknown_municipality
