{# 全国家計構造調査 年間収入階級別の消費支出 (household_structure.income_class_expenditure) の検査。
   結果が0行ならテスト成功。

   - 行が1つも無い (取得の絞りのコードが変わって何も取れなかった)
   - (年, 地域, 年間収入階級, 収支項目) の重複
   - 年間収入階級が 00 平均・01〜40・R1〜R3 の44区分そろわない収支項目
   - 収支項目が消費支出と10大費目の11項目そろわない年間収入階級
   - 10大費目の和が消費支出とずれる。各項目が円未満で丸められているので、11個の値の丸めで
     最大5.5円ずれうる。5円まで許す。2019年の表の実測の最大ずれは2円
   - 01〜40 の消費支出を世帯数分布で加重平均した値が平均 (00) とずれる。世帯数分布が
     推計に使う重みでなくなったら落ちる。1円まで許す。2019年の表の実測のずれは0.35円
   - 付帯値 (集計世帯数・世帯数分布・世帯人員・18歳未満人員・65歳以上人員・有業人員・
     世帯主の年齢) のどれかが NULL の年間収入階級。表章項目のコードが変わって取れなくなったら落ちる #}
{% set items = [
    '2101', '210101', '210102', '210103', '210104', '210105',
    '210106', '210107', '210108', '210109', '210110'
] %}
WITH t AS (
    SELECT * FROM {{ ref('income_class_expenditure') }}
),

empty AS (
    SELECT 'empty' AS check_name, NULL AS key, NULL::DOUBLE AS difference
    FROM (SELECT COUNT(*) AS n FROM t)
    WHERE n = 0
),

duplicated AS (
    SELECT
        'duplicated' AS check_name,
        year || '/' || area || '/' || income_class_code || '/' || item_code AS key,
        COUNT(*)::DOUBLE AS difference
    FROM t
    GROUP BY year, area, income_class_code, item_code
    HAVING COUNT(*) > 1
),

class_codes AS (
    SELECT LPAD(n::VARCHAR, 2, '0') AS income_class_code FROM range(0, 41) AS r(n)
    UNION ALL
    SELECT * FROM (VALUES ('R1'), ('R2'), ('R3')) AS v(income_class_code)
),

item_codes AS (
    SELECT * FROM (VALUES {% for i in items %}('{{ i }}'){{ ", " if not loop.last }}{% endfor %}) AS v(item_code)
),

expected AS (
    SELECT g.year, g.area, c.income_class_code, i.item_code
    FROM (SELECT DISTINCT year, area FROM t) AS g
    CROSS JOIN class_codes AS c
    CROSS JOIN item_codes AS i
),

missing AS (
    SELECT
        'missing' AS check_name,
        e.year || '/' || e.area || '/' || e.income_class_code || '/' || e.item_code AS key,
        NULL::DOUBLE AS difference
    FROM expected AS e
    LEFT JOIN t
        ON e.year = t.year AND e.area = t.area
        AND e.income_class_code = t.income_class_code AND e.item_code = t.item_code
    WHERE t.expenditure IS NULL
),

unexpected AS (
    SELECT
        'unexpected' AS check_name,
        t.year || '/' || t.area || '/' || t.income_class_code || '/' || t.item_code AS key,
        NULL::DOUBLE AS difference
    FROM t
    LEFT JOIN expected AS e
        ON e.year = t.year AND e.area = t.area
        AND e.income_class_code = t.income_class_code AND e.item_code = t.item_code
    WHERE e.item_code IS NULL
),

major_groups AS (
    SELECT
        'major_groups_sum' AS check_name,
        year || '/' || area || '/' || income_class_code AS key,
        MAX(expenditure) FILTER (WHERE item_code = '2101')
            - SUM(expenditure) FILTER (WHERE item_code <> '2101') AS difference
    FROM t
    GROUP BY year, area, income_class_code
    HAVING ABS(difference) > 5
),

weighted AS (
    SELECT
        'weighted_mean' AS check_name,
        year || '/' || area AS key,
        MAX(expenditure) FILTER (WHERE income_class_code = '00')
            - SUM(expenditure * households) FILTER (WHERE NOT is_reclassified AND income_class_code <> '00')
            / SUM(households) FILTER (WHERE NOT is_reclassified AND income_class_code <> '00') AS difference
    FROM t
    WHERE item_code = '2101'
    GROUP BY year, area
    HAVING difference IS NULL OR ABS(difference) > 1
),

attributes_missing AS (
    SELECT
        'attributes_missing' AS check_name,
        year || '/' || area || '/' || income_class_code AS key,
        NULL::DOUBLE AS difference
    FROM t
    WHERE item_code = '2101'
        AND (sample_households IS NULL OR households IS NULL OR household_members IS NULL
            OR members_under_18 IS NULL OR members_65_and_over IS NULL OR earners IS NULL
            OR head_age IS NULL)
)

SELECT * FROM empty
UNION ALL SELECT * FROM duplicated
UNION ALL SELECT * FROM missing
UNION ALL SELECT * FROM unexpected
UNION ALL SELECT * FROM major_groups
UNION ALL SELECT * FROM weighted
UNION ALL SELECT * FROM attributes_missing
