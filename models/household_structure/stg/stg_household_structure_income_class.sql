{# 年間収入階級 × 収支項目 (消費支出と10大費目) を1行にし、同じ収入階級の付帯値を列に並べる。

   付帯値は収支項目の 0 総数 (集計世帯数・世帯数分布) と 1 平均 (世帯人員など) の行にだけ載る。
   世帯数分布は抽出率で調整した推計世帯数で、40区分の消費支出をこれで加重平均すると
   平均 (00) の消費支出に一致する。

   取得は tables.yml の api_params で絞っているが、merge で積むので絞る前に取った行が
   raw に残りうる。ここの世帯の種類・世帯区分・性別・収支項目の絞り込みは外さない。
   消費支出 (2101) と10大費目 (210101〜210110) はコードで固定する。 #}
{% set items = [
    '2101', '210101', '210102', '210103', '210104', '210105',
    '210106', '210107', '210108', '210109', '210110'
] %}
WITH base AS (
    SELECT *
    FROM {{ ref('raw_household_structure_income_class') }}
    WHERE cat01 = '0'
        AND cat02 = '0'
        AND cat03 = '0'
),

expenditure AS (
    SELECT
        area,
        area_metadata->>'$.name' AS area_name,
        time,
        cat05 AS income_class_code,
        cat05_metadata->>'$.name' AS income_class,
        cat04 AS item_code,
        cat04_metadata->>'$.name' AS item_name,
        CASE WHEN cat04 = '2101' THEN NULL ELSE '2101' END AS item_parent,
        value AS expenditure
    FROM base
    WHERE tab = '01-2019'
        AND cat04 IN ({% for i in items %}'{{ i }}'{{ ", " if not loop.last }}{% endfor %})
),

attributes AS (
    SELECT
        area,
        time,
        cat05 AS income_class_code,
        MAX(value) FILTER (WHERE tab = '06-2019' AND cat04 = '0') AS sample_households,
        MAX(value) FILTER (WHERE tab = '07-2019' AND cat04 = '0') AS households,
        MAX(value) FILTER (WHERE tab = '08-2019' AND cat04 = '1') AS household_members,
        MAX(value) FILTER (WHERE tab = '09-2019' AND cat04 = '1') AS members_under_18,
        MAX(value) FILTER (WHERE tab = '10-2019' AND cat04 = '1') AS members_65_and_over,
        MAX(value) FILTER (WHERE tab = '11-2019' AND cat04 = '1') AS earners,
        MAX(value) FILTER (WHERE tab = '12-2019' AND cat04 = '1') AS head_age
    FROM base
    GROUP BY area, time, cat05
),

bounds AS (
    -- 年間収入階級の幅 (万円)。上限は含まない。01〜40 は 100万円未満、100万円から
    -- 2000万円まで50万円刻み、2000万円以上。R1〜R3 は 01〜40 の一部を束ねた再掲
    SELECT
        income_class_code,
        CASE WHEN n = 1 THEN 0 ELSE 50 * n END AS income_lower,
        CASE WHEN n = 40 THEN NULL ELSE 50 * (n + 1) END AS income_upper,
        FALSE AS is_reclassified
    FROM (
        SELECT LPAD(n::VARCHAR, 2, '0') AS income_class_code, n
        FROM range(1, 41) AS t(n)
    )
    UNION ALL
    SELECT * FROM (VALUES
        ('R1', 1000, 1250, TRUE), ('R2', 1250, 1500, TRUE), ('R3', 1500, NULL, TRUE)
    ) AS t(income_class_code, income_lower, income_upper, is_reclassified)
)

SELECT
    e.area,
    e.area_name,
    CAST(LEFT(e.time, 4) AS INTEGER) AS year,
    e.income_class_code,
    e.income_class,
    b.income_lower,
    b.income_upper,
    COALESCE(b.is_reclassified, FALSE) AS is_reclassified,
    e.item_code,
    e.item_name,
    e.item_parent,
    e.expenditure,
    a.sample_households,
    a.households,
    a.household_members,
    a.members_under_18,
    a.members_65_and_over,
    a.earners,
    a.head_age
FROM expenditure AS e
LEFT JOIN attributes AS a
    ON e.area = a.area AND e.time = a.time AND e.income_class_code = a.income_class_code
LEFT JOIN bounds AS b ON e.income_class_code = b.income_class_code
