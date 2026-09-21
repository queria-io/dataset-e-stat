-- kaigo_service の mart が、原典の集計構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 原典は行が地域、列が施設の種類 × 指標の集計表で、見出しの行の位置が年で変わる
-- (2009年調査から注の行が増える)。位置ではなく値の集合から役割を当てているので、
-- 見出しの構成が変わると列の意味が黙って入れ替わる。集計表の足し算が成り立つことが、
-- その検査になる。
--
-- 1) 市区町村が全国に足し上がる。足し合わせて全国になるのは area_kind が
--    municipality と designated_city の行で、行政区 (ward) と特別区部の集計行
--    (district) を足すと二重に数える。施設数と定員はずれ 0 で一致する。
--    常勤換算従事者数だけは原典が 1 の位で丸めた値なので幅を持たせる
--    (実測の最大ずれは市区町村の合計で 118、都道府県の合計で 7)。
--    全国の行があるのは2004年調査からなので、それ以前の年はこの検査に入らない。
--
-- 2) 市区町村が都道府県に足し上がる。政令指定都市の行と行政区の行を取り違えると、
--    全国の検査は通ったまま県の中だけが合わなくなる (実測の最大ずれは
--    常勤換算従事者数で 13、施設数と定員は 0)。
--
-- 3) 都道府県が毎年 47 そろう。行見出しのコードは調査時点のものをそのまま持つので、
--    原典の書式が変わる (2001〜2003年調査の都道府県は 2 桁) とここが落ちる。
--
--    都道府県コードと都道府県名が全国の行以外のすべてに付くことも見る。
--    都道府県名は stg_municipality との結合で付くので、上流の書式が変わると全行
--    NULL のまま公開される。都道府県コードは市区町村 → 都道府県の足し上げの
--    母集団そのもので、全行 NULL に倒れるとその検査ごと消える。どちらも行数も
--    足し算も変えずに落ちるので、ここで名指しで押さえる。
--
-- 4) area_kind が現行の標準地域コード一覧と食い違わない。段はコードの桁から
--    決めているので、code.municipality に残っているコードについては答え合わせが
--    できる (東京23区は municipality、政令指定都市の行政区は ward)。合併で消えた
--    コードは一覧に無いので比べない。
--
-- 5) 年が2001年から連続する。
--
-- 6) 3 つの指標がその年の表にそろう。表題が変わって 1 つの指標だけ取れなくなっても、
--    ほかの指標の行が残るので年の連続でも行数でも気づけない。常勤換算従事者数は
--    2017年調査までしか無いので、そこまでを見る。
--
-- 7) 2012年調査以降は基本票が毎年そろう。詳細票だけが残ると、回収率の影響を受ける
--    系列に黙って入れ替わる。
--
-- 8) 値が全部 NULL に倒れていない。その年その市区町村にその種類の施設が無ければ
--    NULL なので NOT NULL は使えない (実測: 非 NULL は年・指標ごとに 51.7%〜72.3%)。
--    原典が表記を変えてローダーが値を読めなくなると、行数も年も地域も正しいまま
--    値だけ消えてほかの検査を素通りするので、下から押さえる。

{% set rollup_tolerance = {
    'facility_count': 0, 'capacity': 0, 'fte_workers': 118
} %}
{% set prefecture_tolerance = {
    'facility_count': 0, 'capacity': 0, 'fte_workers': 13
} %}
{% set min_non_null_pct = 40 %}
{% set first_survey_year = 2001 %}
{% set first_nationwide_year = 2004 %}
{% set first_split_year = 2012 %}
{% set last_fte_year = 2017 %}
{% set municipality_kinds = ['municipality', 'designated_city'] %}

WITH stats AS (
    SELECT * FROM {{ ref('insurance_facility') }}
),

-- 1) 市区町村の合計 = 全国
nationwide_failures AS (
    SELECT
        'nationwide_rollup' AS check_name,
        survey_year
            || ' ' || measure
            || ' ' || COALESCE(survey_form, '-')
            || ' ' || facility_type AS detail
    FROM stats
    WHERE survey_year >= {{ first_nationwide_year }}
    GROUP BY survey_year, measure, survey_form, facility_type
    HAVING ABS(
        COALESCE(SUM(COALESCE(value, 0)) FILTER (WHERE area_kind = 'nationwide'), 0)
        - COALESCE(SUM(COALESCE(value, 0)) FILTER (
            WHERE area_kind IN (
                {%- for kind in municipality_kinds %}
                '{{ kind }}'{{ "," if not loop.last }}
                {%- endfor %}
            )
        ), 0)
    ) > CASE measure
        {%- for name, tolerance in rollup_tolerance.items() %}
        WHEN '{{ name }}' THEN {{ tolerance }}
        {%- endfor %}
        -- 知らない指標は幅 0 で見る。ELSE を省くと CASE が NULL になり、
        -- 増えた指標だけがこの検査から外れる。
        ELSE 0
    END
),

-- 2) 市区町村の合計 = 都道府県
prefecture_failures AS (
    SELECT
        'prefecture_rollup' AS check_name,
        survey_year
            || ' ' || measure
            || ' ' || COALESCE(survey_form, '-')
            || ' ' || facility_type
            || ' ' || prefecture_code AS detail
    FROM stats
    WHERE prefecture_code IS NOT NULL
    GROUP BY survey_year, measure, survey_form, facility_type, prefecture_code
    HAVING ABS(
        COALESCE(SUM(COALESCE(value, 0)) FILTER (WHERE area_kind = 'prefecture'), 0)
        - COALESCE(SUM(COALESCE(value, 0)) FILTER (
            WHERE area_kind IN (
                {%- for kind in municipality_kinds %}
                '{{ kind }}'{{ "," if not loop.last }}
                {%- endfor %}
            )
        ), 0)
    ) > CASE measure
        {%- for name, tolerance in prefecture_tolerance.items() %}
        WHEN '{{ name }}' THEN {{ tolerance }}
        {%- endfor %}
        ELSE 0
    END
),

-- 3) 都道府県が 47 そろい、コードが付く
prefecture_count_failures AS (
    SELECT
        'prefecture_count' AS check_name,
        survey_year || ' ' || COUNT(DISTINCT area_code) || ' 都道府県' AS detail
    FROM stats
    WHERE area_kind = 'prefecture'
    GROUP BY survey_year
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

-- 4) 段が現行の標準地域コード一覧と食い違わない
kind_failures AS (
    SELECT DISTINCT
        'area_kind_mismatch' AS check_name,
        s.area_code || ' ' || s.area_name
            || ' ' || s.area_kind || ' <> ' || m.area_kind AS detail
    FROM stats s
    JOIN {{ ref('municipality') }} m ON m.area_code = s.area_code
    WHERE s.area_kind <> m.area_kind
),

-- 5) 年が連続する
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

-- 6) 指標がその年の表にそろう
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
        {%- for measure in ['facility_count', 'capacity', 'fte_workers'] %}
        ('{{ measure }}'){{ "," if not loop.last }}
        {%- endfor %}
    ) AS expected(measure)
    WHERE (expected.measure <> 'fte_workers' OR year <= {{ last_fte_year }})
        AND NOT EXISTS (
            SELECT 1 FROM stats s
            WHERE s.survey_year = year AND s.measure = expected.measure
        )
),

empty_failures AS (
    SELECT 'table_is_empty' AS check_name, '0 行' AS detail
    WHERE (SELECT COUNT(*) FROM stats) = 0
),

-- 7) 2012年調査以降は基本票がそろう
form_failures AS (
    SELECT
        'basic_form_missing' AS check_name,
        CAST(year AS VARCHAR) AS detail
    FROM (
        SELECT UNNEST(RANGE(
            {{ first_split_year }}, COALESCE((SELECT MAX(survey_year) FROM stats), 0) + 1
        )) AS year
    )
    WHERE NOT EXISTS (
        SELECT 1 FROM stats s
        WHERE s.survey_year = year AND s.survey_form = '基本票'
    )
),

-- 8) 値が全部 NULL に倒れていない
value_failures AS (
    SELECT
        'value_all_null' AS check_name,
        survey_year || ' ' || measure || ' '
            || ROUND(100.0 * COUNT(value) / COUNT(*), 1) || '%' AS detail
    FROM stats
    GROUP BY survey_year, measure
    HAVING 100.0 * COUNT(value) / COUNT(*) < {{ min_non_null_pct }}
)

SELECT * FROM nationwide_failures
UNION ALL SELECT * FROM prefecture_failures
UNION ALL SELECT * FROM prefecture_count_failures
UNION ALL SELECT * FROM area_column_failures
UNION ALL SELECT * FROM kind_failures
UNION ALL SELECT * FROM year_failures
UNION ALL SELECT * FROM coverage_failures
UNION ALL SELECT * FROM empty_failures
UNION ALL SELECT * FROM form_failures
UNION ALL SELECT * FROM value_failures
