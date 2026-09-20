-- welfare_facility の mart が、原典の集計構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 原典は行が地域、列が施設の種類 × 経営主体の集計表で、見出しが年ごとに 3〜6 行
-- 重なる。行の位置ではなく値の集合から役割を当てているので、見出しの構成が変わると
-- 列の意味が黙って入れ替わる。集計表の足し算が成り立つことが、その検査になる。
--
-- 1) 施設の種類の段が総数と一致する。facility_level='type' の列だけが足し合わせて
--    全体になる段で、大分類の小計('group')・保育所等の内訳('detail')・再掲('reprint')
--    を混ぜると二重に数える。原典が総数から外している施設は差し引いてから比べる
--    (実測: 定員・在所者数の総数は母子生活支援施設を含まない。2011年調査は定員から
--    助産施設も外れる。いずれも CSV の注に書いてある)。
--    許す幅は指標ごとに違う。施設数は 1 のずれも無く一致する。定員は ±3、在所者数は
--    ±2、常勤換算従事者数は ±6 (実測の最大ずれ。原典が 1 の位で丸めた値を足すため)。
--    FILTER の集計は該当行が無いと 0 ではなく NULL を返し、NULL との比較は偽になって
--    検査ごと素通りする。差し引く項は必ず COALESCE で 0 に倒す。
--
-- 2) 経営主体が公営と私営に割り切れる。総数 = 公営 + 私営。丸めで ±1。
--
-- 3) 地域が全国に足し上がる。2017年調査までは指定都市・中核市が都道府県とは別の行に
--    並び、都道府県の行はその分を含まない (実測: 2017年調査の基本票の定員は全国 3,875,461 =
--    国 1,308 + 都道府県 2,511,610 + 指定都市 783,741 + 中核市 578,802)。ここが崩れると
--    都道府県を足しても全国にならず、市の行を落としたことに気づけない。丸めで ±12。
--
-- 4) 都道府県が毎年 47 そろい、標準地域コードが付く。市の行も含めてコードが付かない
--    のは全国と国の 2 行だけ。名前で突き合わせているので、原典の表記が変わると
--    ここが落ちる (実測: 都道府県名は2022年調査まで「青森」、2023年調査から「青森県」)。
--
-- 5) 値が全部 NULL に倒れていない。その年その県にその種類の施設が無ければ NULL なので
--    NOT NULL は使えない (実測: 非 NULL は年・指標ごとに 34.4%〜63.3%)。原典が表記を
--    変えてローダーが値を読めなくなると、行数も年も県も正しいまま値だけ消えて
--    ほかの検査を素通りするので、下から押さえる。
--
-- 6) 4 つの指標が毎年そろう。表題が変わって 1 つの指標だけが取れなくなっても、ほかの
--    指標の行が残るので年の連続も足し算も通ってしまう。指標 × 年で数える。
--    表が 1 つも取れなかったときはここまでの検査が全部グループ 0 で通るので、
--    行数そのものも見る。
--
-- 7) 大分類が全部の施設の種類に付く。2014年調査までの定員・在所者数は原典が大分類を
--    印字しないので、stg が符号から補っている。補完が外れても行数も足し算も変わらず、
--    大分類でまとめた集計だけがその 4 年ぶん静かに落ちる。大分類に属さないのは
--    婦人保護施設と女性自立支援施設だけ (実測)。

{% set partition_tolerance = {
    'facility_count': 0, 'capacity': 3, 'occupants': 2, 'fte_workers': 6
} %}
{% set operator_tolerance = 1 %}
{% set area_tolerance = 12 %}
{% set min_non_null_pct = 25 %}
{% set first_survey_year = 2011 %}
{% set ungrouped_types = ['婦人保護施設', '女性自立支援施設'] %}

WITH stats AS (
    SELECT * FROM {{ ref('facility_statistics') }}
),

-- 1) 施設の種類の段の合計と総数
partition_check AS (
    SELECT
        'facility_type_partition' AS check_name,
        survey_year
            || ' ' || measure
            || ' ' || COALESCE(survey_form, '-')
            || ' ' || area_name
            || ' ' || operator AS detail,
        measure,
        COALESCE(
            SUM(COALESCE(value, 0)) FILTER (WHERE facility_level = 'type'), 0
        ) AS total_of_parts,
        -- 原典が総数から外している施設。
        COALESCE(SUM(COALESCE(value, 0)) FILTER (
            WHERE facility_level = 'type'
                AND measure IN ('capacity', 'occupants')
                AND facility_type = '母子生活支援施設'
        ), 0) AS excluded_mother_child,
        COALESCE(SUM(COALESCE(value, 0)) FILTER (
            WHERE facility_level = 'type'
                AND measure = 'capacity'
                AND survey_year = 2011
                AND facility_type = '助産施設'
        ), 0) AS excluded_maternity,
        COALESCE(
            SUM(COALESCE(value, 0)) FILTER (WHERE facility_level = 'total'), 0
        ) AS published_total
    FROM stats
    GROUP BY survey_year, measure, survey_form, area_name, operator
),

partition_failures AS (
    SELECT check_name, detail
    FROM partition_check
    WHERE ABS(
        total_of_parts - excluded_mother_child - excluded_maternity - published_total
    ) > CASE measure
        {%- for name, tolerance in partition_tolerance.items() %}
        WHEN '{{ name }}' THEN {{ tolerance }}
        {%- endfor %}
        -- 知らない指標は幅 0 で見る。ELSE を省くと CASE が NULL になり、
        -- 増えた指標だけがこの検査から外れる。
        ELSE 0
    END
),

-- 2) 公営 + 私営 = 総数
operator_failures AS (
    SELECT
        'operator_split' AS check_name,
        survey_year || ' ' || measure || ' ' || area_name || ' ' || facility_type
            AS detail
    FROM stats
    GROUP BY survey_year, measure, survey_form, area_name, facility_type, facility_level
    HAVING ABS(
        COALESCE(SUM(COALESCE(value, 0)) FILTER (WHERE operator = '総数'), 0)
        - COALESCE(SUM(COALESCE(value, 0)) FILTER (WHERE operator <> '総数'), 0)
    ) > {{ operator_tolerance }}
),

-- 3) 国 + 都道府県 + 指定都市 + 中核市 = 全国
area_failures AS (
    SELECT
        'area_rollup' AS check_name,
        survey_year || ' ' || measure || ' ' || facility_type || ' ' || operator
            AS detail
    FROM stats
    GROUP BY survey_year, measure, survey_form, facility_type, facility_level, operator
    HAVING ABS(
        COALESCE(SUM(COALESCE(value, 0)) FILTER (WHERE area_kind = 'nationwide'), 0)
        - COALESCE(SUM(COALESCE(value, 0)) FILTER (WHERE area_kind <> 'nationwide'), 0)
    ) > {{ area_tolerance }}
),

-- 4) 都道府県が 47 そろい、コードが付く
prefecture_failures AS (
    SELECT
        'prefecture_count' AS check_name,
        survey_year || ' ' || COUNT(DISTINCT area_name) || ' 都道府県' AS detail
    FROM stats
    WHERE area_kind = 'prefecture'
    GROUP BY survey_year
    HAVING COUNT(DISTINCT area_name) <> 47
),

code_failures AS (
    SELECT DISTINCT
        'area_code_missing' AS check_name,
        area_kind || ' ' || area_name AS detail
    FROM stats
    WHERE area_code IS NULL AND area_kind NOT IN ('nationwide', 'state')
),

year_failures AS (
    SELECT
        'survey_year_gap' AS check_name,
        CAST(year AS VARCHAR) AS detail
    FROM (
        SELECT UNNEST(RANGE(
            {{ first_survey_year }}, (SELECT MAX(survey_year) FROM stats) + 1
        )) AS year
    )
    WHERE year NOT IN (SELECT DISTINCT survey_year FROM stats)
),

-- 5) 値が全部 NULL に倒れていない
value_failures AS (
    SELECT
        'value_all_null' AS check_name,
        survey_year || ' ' || measure || ' '
            || ROUND(100.0 * COUNT(value) / COUNT(*), 1) || '%' AS detail
    FROM stats
    GROUP BY survey_year, measure
    HAVING 100.0 * COUNT(value) / COUNT(*) < {{ min_non_null_pct }}
),

-- 6) 4 つの指標が毎年そろい、表が空でない
coverage_failures AS (
    SELECT
        'measure_missing' AS check_name,
        year || ' ' || measure AS detail
    FROM (
        SELECT UNNEST(RANGE(
            {{ first_survey_year }}, COALESCE((SELECT MAX(survey_year) FROM stats), 0) + 1
        )) AS year
    )
    CROSS JOIN (VALUES
        {%- for measure in ['facility_count', 'capacity', 'occupants', 'fte_workers'] %}
        ('{{ measure }}'){{ "," if not loop.last }}
        {%- endfor %}
    ) AS expected(measure)
    WHERE NOT EXISTS (
        SELECT 1 FROM stats s
        WHERE s.survey_year = year AND s.measure = expected.measure
    )
),

empty_failures AS (
    SELECT 'table_is_empty' AS check_name, '0 行' AS detail
    WHERE (SELECT COUNT(*) FROM stats) = 0
),

-- 7) 大分類が全部の施設の種類に付く
group_failures AS (
    SELECT DISTINCT
        'facility_group_missing' AS check_name,
        survey_year || ' ' || measure || ' ' || facility_type AS detail
    FROM stats
    WHERE facility_level = 'type'
        AND facility_group IS NULL
        AND facility_type NOT IN (
            {%- for name in ungrouped_types %}
            '{{ name }}'{{ "," if not loop.last }}
            {%- endfor %}
        )
)

SELECT * FROM partition_failures
UNION ALL SELECT * FROM operator_failures
UNION ALL SELECT * FROM area_failures
UNION ALL SELECT * FROM prefecture_failures
UNION ALL SELECT * FROM code_failures
UNION ALL SELECT * FROM year_failures
UNION ALL SELECT * FROM value_failures
UNION ALL SELECT * FROM coverage_failures
UNION ALL SELECT * FROM empty_failures
UNION ALL SELECT * FROM group_failures
