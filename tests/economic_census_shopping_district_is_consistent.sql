-- 経済センサス 商業集積地区別の表 (shopping_district) の整合を検証する。結果が0行ならテスト成功。
--
-- 1. 段ごとの数 (全国1・都道府県47・市区町村1,334・区197・地区12,535) が原典どおりで、
--    地区 (計) × 産業が1行ずつ (3区分) そろっている。重複は mart の GROUP BY が MAX で
--    1行に潰すので、stg で地区 × 産業 × 表章項目が1行ずつかを見る
-- 2. 全国の計が原典の値に一致する
-- 3. 親 (parent_district_code) が1つ上の段に実在し、地区の area が親と同じ市区町村・区を指す。
--    どの行も段 (district_level) が決まり、地区には立地環境特性の細分類があり、計の行には無い
-- 4. 親の計が子の和に一致する (地区 → 市区町村・区、区 → 政令指定都市・特別区部、
--    市区町村 → 都道府県、都道府県 → 全国)。事業所数・大規模小売店舗内事業所数・従業者数は
--    ちょうど一致する。売上（収入）金額は原典が区分ごとに丸めるので、(足した行数 + 1) × 0.5
--    までのずれを許す。売上（収入）金額・売場面積は、NULL (秘匿) を含む組では一致を見ない
--    代わりに、分かっている子の和が親を超えないことを見る
-- 5. 大規模小売店舗内事業所数が事業所数を超えない
--
-- 元表は手元でだけ取り込む (load_local.py economic_census_shopping_district)。元表が無い
-- カタログ (CI でまだ公開していないとき) では 0 行の表になるので検査しない。

{% if local_source_loaded('economic_census_shopping_district') %}
WITH r AS (
    SELECT * FROM {{ ref('shopping_district') }}
),

level_counts AS (
    SELECT
        'district_level ' || l.district_level AS check_name,
        COUNT(DISTINCT r.district_code) AS actual,
        l.expected
    FROM (VALUES ('national', 1), ('prefecture', 47), ('municipality', 1334), ('ward', 197), ('district', 12535))
        AS l (district_level, expected)
    LEFT JOIN r USING (district_level)
    GROUP BY ALL
    HAVING COUNT(DISTINCT r.district_code) <> l.expected
),

cells AS (
    SELECT 'cells ' || district_code AS check_name, COUNT(*) AS actual, 3 AS expected
    FROM r
    GROUP BY district_code
    HAVING COUNT(*) <> 3 OR COUNT(DISTINCT industry_code) <> 3
),

duplicates AS (
    SELECT 'duplicate ' || district_code || ' ' || industry_code || ' ' || tab AS check_name,
        COUNT(*) AS actual, 1 AS expected
    FROM {{ ref('stg_economic_census_shopping_district') }}
    GROUP BY district_code, industry_code, tab
    HAVING COUNT(*) > 1
),

national AS (
    SELECT 'national ' || r.industry_code || ' ' || m.name AS check_name, m.actual, m.expected
    FROM r
    JOIN (VALUES
        ('I2', 259039, 74523, 2316334, 49823750, 54794283),
        ('M2', 188254, 21084, 1432843, 5737129, NULL),
        ('N', 93803, 11845, 360004, 2536656, NULL)
    ) AS e (industry_code, est, large, emp, sales, floor) USING (industry_code),
        LATERAL (VALUES
            ('establishments', r.establishments, e.est),
            ('establishments_in_large_stores', r.establishments_in_large_stores, e.large),
            ('employees', r.employees, e.emp),
            ('sales_million_yen', r.sales_million_yen, e.sales),
            ('floor_area_m2', r.floor_area_m2, e.floor)
        ) AS m (name, actual, expected)
    WHERE r.district_level = 'national'
        AND m.actual IS DISTINCT FROM m.expected
),

-- 子の段と、親に許す段
parent_levels AS (
    SELECT * FROM (VALUES
        ('prefecture', 'national'),
        ('municipality', 'prefecture'),
        ('ward', 'municipality'),
        ('district', 'municipality'),
        ('district', 'ward')
    ) AS t (child_level, parent_level)
),

orphans AS (
    SELECT 'parent ' || c.district_code || ' -> ' || COALESCE(c.parent_district_code, 'NULL') AS check_name,
        NULL::BIGINT AS actual, NULL::BIGINT AS expected
    FROM r AS c
    WHERE c.district_level <> 'national' AND c.industry_code = 'I2'
        AND NOT EXISTS (
            SELECT 1
            FROM r AS p
            JOIN parent_levels AS l ON l.parent_level = p.district_level
            WHERE p.district_code = c.parent_district_code AND p.industry_code = 'I2'
                AND l.child_level = c.district_level
                AND (c.district_level <> 'district' OR p.area = c.area)
        )
),

district_types AS (
    SELECT 'district_type ' || district_code AS check_name, NULL::BIGINT AS actual, NULL::BIGINT AS expected
    FROM r
    WHERE district_level IS NULL
        OR (district_level = 'district') <> (district_type IS NOT NULL)
),

pairs AS (
    SELECT p.district_code, p.industry_code, p, c
    FROM r AS p
    JOIN r AS c ON c.parent_district_code = p.district_code AND c.industry_code = p.industry_code
),

sums AS (
    SELECT
        district_code, industry_code,
        COUNT(*) AS n,
        ANY_VALUE(p).establishments AS p_est, SUM(c.establishments) AS c_est,
        ANY_VALUE(p).establishments_in_large_stores AS p_large,
        SUM(c.establishments_in_large_stores) AS c_large,
        ANY_VALUE(p).employees AS p_emp, SUM(c.employees) AS c_emp,
        ANY_VALUE(p).sales_million_yen AS p_sales, SUM(c.sales_million_yen) AS c_sales,
        COUNT(*) FILTER (WHERE c.sales_million_yen IS NULL) AS sales_null,
        ANY_VALUE(p).floor_area_m2 AS p_floor, SUM(c.floor_area_m2) AS c_floor,
        COUNT(*) FILTER (WHERE c.floor_area_m2 IS NULL) AS floor_null
    FROM pairs
    GROUP BY ALL
),

mismatches AS (
    SELECT 'establishments ' || district_code || ' ' || industry_code AS check_name,
        c_est AS actual, p_est AS expected
    FROM sums WHERE p_est <> c_est
    UNION ALL
    SELECT 'establishments_in_large_stores ' || district_code || ' ' || industry_code, c_large, p_large
    FROM sums WHERE p_large <> c_large
    UNION ALL
    SELECT 'employees ' || district_code || ' ' || industry_code, c_emp, p_emp
    FROM sums WHERE p_emp <> c_emp
    UNION ALL
    SELECT 'sales ' || district_code || ' ' || industry_code, c_sales, p_sales
    FROM sums
    WHERE sales_null = 0 AND p_sales IS NOT NULL AND ABS(p_sales - c_sales) > (n + 1) * 0.5
    UNION ALL
    SELECT 'sales upper bound ' || district_code || ' ' || industry_code, c_sales, p_sales
    FROM sums
    WHERE sales_null > 0 AND c_sales - p_sales > (n - sales_null + 1) * 0.5
    UNION ALL
    SELECT 'floor ' || district_code, c_floor, p_floor
    FROM sums
    WHERE industry_code = 'I2' AND floor_null = 0 AND p_floor IS NOT NULL AND p_floor <> c_floor
    UNION ALL
    SELECT 'floor upper bound ' || district_code, c_floor, p_floor
    FROM sums
    WHERE industry_code = 'I2' AND floor_null > 0 AND c_floor > p_floor
),

large_stores AS (
    SELECT 'large stores ' || district_code || ' ' || industry_code AS check_name,
        establishments_in_large_stores AS actual, establishments AS expected
    FROM r
    WHERE establishments_in_large_stores > establishments
)

SELECT check_name, actual, expected FROM level_counts
UNION ALL SELECT check_name, actual, expected FROM cells
UNION ALL SELECT check_name, actual, expected FROM duplicates
UNION ALL SELECT check_name, actual, expected FROM national
UNION ALL SELECT check_name, actual, expected FROM orphans
UNION ALL SELECT check_name, actual, expected FROM district_types
UNION ALL SELECT check_name, actual, expected FROM mismatches
UNION ALL SELECT check_name, actual, expected FROM large_stores
{% else %}
SELECT NULL::VARCHAR AS check_name, NULL::BIGINT AS actual, NULL::BIGINT AS expected
WHERE FALSE
{% endif %}
