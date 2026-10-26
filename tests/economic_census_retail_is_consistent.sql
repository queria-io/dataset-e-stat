-- 経済センサス 小売業の市区町村別の表 (retail_municipality) の整合を検証する。結果が0行ならテスト成功。
--
-- 1. 地域の段ごとの数が establishment_industry と同じ (全国1・都道府県47・市町村と特別区部1,719・
--    区199) で、地域 × 産業が1行ずつ (7区分) そろっている。2つの統計表から市と町村を
--    つないでいるので、片方の取り違えは段の数のずれか重複に出る
-- 2. 全国の小売業計が原典の値 (事業所数 755,015・従業者数 6,464,650・年間商品販売額
--    133,257,457 百万円) に一致する
-- 3. 都道府県の値が市町村の和に、政令指定都市・特別区部の値が区の和に、小売業計が中分類の
--    和に一致する。年間商品販売額は原典が区分ごとに丸めるので、足した行数 × 0.5 までの
--    ずれを許す。年間商品販売額・売場面積は NULL (秘匿) を含む組を見ない。無店舗小売業 (61) は
--    売場面積を持たないので、売場面積は 61 を除いて足す (小売業計の売場面積は 56〜60 の和)
--
-- 元表は手元でだけ取り込む (load_local.py economic_census_retail)。元表が無いカタログ
-- (CI でまだ公開していないとき) では 0 行の表になるので検査しない。

{% if local_source_loaded('economic_census_retail_city') and local_source_loaded('economic_census_retail_town') %}
WITH r AS (
    SELECT * FROM {{ ref('retail_municipality') }}
),

level_counts AS (
    SELECT
        'area_level ' || l.area_level AS check_name,
        COUNT(DISTINCT r.area) AS actual,
        l.expected
    FROM (VALUES ('national', 1), ('prefecture', 47), ('municipality', 1719), ('ward', 199))
        AS l (area_level, expected)
    LEFT JOIN r USING (area_level)
    GROUP BY ALL
    HAVING COUNT(DISTINCT r.area) <> l.expected
),

cells AS (
    SELECT 'cells ' || area AS check_name, COUNT(*) AS actual, 7 AS expected
    FROM r
    GROUP BY area
    HAVING COUNT(*) <> 7 OR COUNT(DISTINCT industry_code) <> 7
),

national AS (
    SELECT 'national ' || m.name AS check_name, m.actual, m.expected
    FROM r,
        LATERAL (VALUES
            ('establishments', r.establishments, 755015),
            ('employees', r.employees, 6464650),
            ('sales_million_yen', r.sales_million_yen, 133257457)
        ) AS m (name, actual, expected)
    WHERE r.area = '00000' AND r.industry_code = 'I2'
        AND m.actual IS DISTINCT FROM m.expected
),

-- 親と子の組。都道府県 ← 市町村、政令指定都市・特別区部 ← 区、小売業計 ← 中分類
pairs AS (
    SELECT 'pref' AS kind, p.area, p.industry_code, p, c
    FROM r AS p
    JOIN r AS c ON c.parent_area = p.area AND c.industry_code = p.industry_code
    WHERE p.area_level = 'prefecture' AND c.area_level = 'municipality'
    UNION ALL
    SELECT 'ward', p.area, p.industry_code, p, c
    FROM r AS p
    JOIN r AS c ON c.parent_area = p.area AND c.industry_code = p.industry_code
    WHERE c.area_level = 'ward'
    UNION ALL
    SELECT 'industry', p.area, p.industry_code, p, c
    FROM r AS p
    JOIN r AS c ON c.area = p.area AND c.parent_industry = p.industry_code
),

sums AS (
    SELECT
        kind, area, industry_code,
        COUNT(*) AS n,
        ANY_VALUE(p).establishments AS p_est, SUM(c.establishments) AS c_est,
        ANY_VALUE(p).employees AS p_emp, SUM(c.employees) AS c_emp,
        ANY_VALUE(p).sales_million_yen AS p_sales, SUM(c.sales_million_yen) AS c_sales,
        COUNT(*) FILTER (WHERE c.sales_million_yen IS NULL) AS sales_null,
        ANY_VALUE(p).floor_area_m2 AS p_floor,
        SUM(c.floor_area_m2) FILTER (WHERE c.industry_code <> '61') AS c_floor,
        COUNT(*) FILTER (WHERE c.floor_area_m2 IS NULL AND c.industry_code <> '61') AS floor_null
    FROM pairs
    GROUP BY ALL
),

mismatches AS (
    SELECT kind || ' establishments ' || area || ' ' || industry_code AS check_name,
        c_est AS actual, p_est AS expected
    FROM sums WHERE p_est <> c_est
    UNION ALL
    SELECT kind || ' employees ' || area || ' ' || industry_code, c_emp, p_emp
    FROM sums WHERE p_emp <> c_emp
    UNION ALL
    SELECT kind || ' sales ' || area || ' ' || industry_code, c_sales, p_sales
    FROM sums
    WHERE sales_null = 0 AND p_sales IS NOT NULL AND ABS(p_sales - c_sales) > n * 0.5
    UNION ALL
    SELECT kind || ' floor ' || area || ' ' || industry_code, c_floor, p_floor
    FROM sums
    WHERE floor_null = 0 AND p_floor IS NOT NULL AND p_floor <> c_floor
)

SELECT check_name, actual, expected FROM level_counts
UNION ALL SELECT check_name, actual, expected FROM cells
UNION ALL SELECT check_name, actual, expected FROM national
UNION ALL SELECT check_name, actual, expected FROM mismatches
{% else %}
SELECT NULL::VARCHAR AS check_name, NULL::BIGINT AS actual, NULL::BIGINT AS expected
WHERE FALSE
{% endif %}
