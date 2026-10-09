-- kaigo_service.service_establishment が、原典の集計構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 原典は行が地域、列がサービスの種類の表で、地域名から役割 (全国・都道府県・
-- 再掲の指定都市・中核市) を当てている。再掲の見出しの読み違いや列のずれは
-- 行数を変えずに起きるので、表の足し算で押さえる。
--
-- 1) 都道府県が全国に足し上がる。足すのは prefecture の行だけで、指定都市・中核市は
--    都道府県の内数の再掲 (実測: ずれ 0)。
--
-- 2) 指定都市・中核市の合計が、その都道府県の値を超えない。再掲の見出しを
--    読み落として市の行を都道府県に数えると 1) は崩れるが、市の行が別の県に
--    当たると 1) は通ったままここだけが崩れる。
--
-- 3) 都道府県が年・区分ごとに 47 そろい、全国以外の行に都道府県コードが付く。
--    コードは地域名の結合で付くので、名前の表記が変わると行数も足し算も
--    変えずに NULL に倒れる。
--
-- 4) 2013年調査から年が連続し、4 つの区分が毎年そろう。1 表だけ表題が変わって
--    落ちても、ほかの表の行で年はそろって見える。
--
-- 5) 値が全部 NULL に倒れていない。「-」(該当なし) は NULL なので NOT NULL は
--    使えない (実測: 非 NULL は年ごとに 94.9%〜97.2%)。

{% set first_survey_year = 2013 %}
{% set min_non_null_pct = 80 %}
{% set categories = [
    '居宅サービス', '介護予防サービス', '地域密着型サービス', '地域密着型介護予防サービス'
] %}

WITH stats AS (
    SELECT * FROM {{ ref('service_establishment') }}
),

-- 1) 都道府県の合計 = 全国
nationwide_failures AS (
    SELECT
        'nationwide_rollup' AS check_name,
        survey_year || ' ' || service_category || ' ' || service_type AS detail
    FROM stats
    GROUP BY survey_year, service_category, service_type
    HAVING COALESCE(SUM(value) FILTER (WHERE area_kind = 'nationwide'), 0)
        <> COALESCE(SUM(value) FILTER (WHERE area_kind = 'prefecture'), 0)
),

-- 2) 指定都市・中核市の合計 <= 都道府県
city_failures AS (
    SELECT
        'city_exceeds_prefecture' AS check_name,
        survey_year || ' ' || service_type || ' ' || prefecture_code AS detail
    FROM stats
    WHERE prefecture_code IS NOT NULL
    GROUP BY survey_year, service_category, service_type, prefecture_code
    HAVING COALESCE(SUM(value) FILTER (
            WHERE area_kind IN ('designated_city', 'core_city')
        ), 0)
        > COALESCE(SUM(value) FILTER (WHERE area_kind = 'prefecture'), 0)
),

-- 3) 都道府県が 47 そろい、コードが付く
prefecture_count_failures AS (
    SELECT
        'prefecture_count' AS check_name,
        survey_year || ' ' || service_category
            || ' ' || COUNT(DISTINCT area_code) || ' 都道府県' AS detail
    FROM stats
    WHERE area_kind = 'prefecture'
    GROUP BY survey_year, service_category
    HAVING COUNT(DISTINCT area_code) <> 47
),

area_column_failures AS (
    SELECT
        'prefecture_column_null' AS check_name,
        column_name || ' が ' || null_rows || ' 行 NULL' AS detail
    FROM (
        SELECT 'prefecture_code' AS column_name,
            COUNT(*) FILTER (WHERE prefecture_code IS NULL) AS null_rows
        FROM stats WHERE area_kind <> 'nationwide'
        UNION ALL
        SELECT 'prefecture_name',
            COUNT(*) FILTER (WHERE prefecture_name IS NULL)
        FROM stats WHERE area_kind <> 'nationwide'
    )
    WHERE null_rows > 0
),

-- 4) 年と区分がそろう
coverage_failures AS (
    SELECT
        'category_missing' AS check_name,
        year || ' ' || expected.category AS detail
    FROM (
        SELECT UNNEST(RANGE(
            {{ first_survey_year }}, COALESCE((SELECT MAX(survey_year) FROM stats), 0) + 1
        )) AS year
    )
    CROSS JOIN (VALUES
        {%- for category in categories %}
        ('{{ category }}'){{ "," if not loop.last }}
        {%- endfor %}
    ) AS expected(category)
    WHERE NOT EXISTS (
        SELECT 1 FROM stats s
        WHERE s.survey_year = year AND s.service_category = expected.category
    )
),

empty_failures AS (
    SELECT 'table_is_empty' AS check_name, '0 行' AS detail
    WHERE (SELECT COUNT(*) FROM stats) = 0
),

-- 5) 値が全部 NULL に倒れていない
value_failures AS (
    SELECT
        'value_all_null' AS check_name,
        survey_year || ' ' || ROUND(100.0 * COUNT(value) / COUNT(*), 1) || '%' AS detail
    FROM stats
    GROUP BY survey_year
    HAVING 100.0 * COUNT(value) / COUNT(*) < {{ min_non_null_pct }}
)

SELECT * FROM nationwide_failures
UNION ALL SELECT * FROM city_failures
UNION ALL SELECT * FROM prefecture_count_failures
UNION ALL SELECT * FROM area_column_failures
UNION ALL SELECT * FROM coverage_failures
UNION ALL SELECT * FROM empty_failures
UNION ALL SELECT * FROM value_failures
