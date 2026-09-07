-- municipality_industry で、産業と地域の総数・内訳の恒等式が成り立つことを検証する。
-- 結果が0行ならテスト成功。
--
-- 産業は製造業計(00)と中分類24区分が同じ列に縦に並ぶ。階層は industry_level にしか
-- 出ていないので、原典のコードが振り直されると行数も粒度も変わらないまま「合計に
-- 使える行」の集合だけがずれる。恒等式と、区分のコードが原典どおり揃っていることを
-- 併せて見る。区分の顔ぶれは年単位で見る。地域ごとの行は該当のある産業しか無く、
-- 中分類が24区分そろう地域のほうが少ない。
--
-- 恒等式に使えるのは事業所数と従業者数だけ。金額の項目は事業所が少ない区分を秘匿する
-- ため内訳の和が総数に届かない（製造品出荷額等で中央値94%）。
--
-- 産業の内訳は市区町村と区の行にしかない。都道府県・政令指定都市・東京特別区の行と、
-- 事業所の少ない市町村は製造業計しか持たないので、内訳を持つ地域だけで見る。
--
-- 長野県の2020年だけ、都道府県(4,767事業所・202,222人)と市区町村の和(4,766事業所・
-- 202,218人)が1事業所ぶんずれる。原典の不整合なので明示的に除く。ここを丸めて
-- 「差が小さければ通す」にすると、ほかの県で内訳が丸ごと落ちる壊れ方を拾えなくなる。

-- industry_level は e-Stat のメタ情報の level から作っている。振り直されて数値でなく
-- なると TRY_CAST が黙って NULL に落とし、breakdown_rows が全地域で 0 になって
-- 恒等式の2本が「対象0行 = 合格」を返す。階層そのものを先に見る。

{% set industry_codes = [
    '00',
    '09', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20',
    '21', '22', '23', '24', '25', '26', '27', '28', '29', '30', '31', '32'
] %}

WITH by_year AS (
    SELECT
        survey_year,
        LIST_SORT(ARRAY_AGG(DISTINCT industry_code)) AS category_codes
    FROM {{ ref('municipality_industry') }}
    GROUP BY survey_year
),

by_industry AS (
    SELECT
        survey_year,
        area,
        COUNT(*) FILTER (WHERE industry_level = 2) AS breakdown_rows,
        MAX(establishments) FILTER (WHERE industry_code = '00') AS total,
        SUM(establishments) FILTER (WHERE industry_level = 2) AS breakdown_sum,
        MAX(employees) FILTER (WHERE industry_code = '00') AS employee_total,
        SUM(employees) FILTER (WHERE industry_level = 2) AS employee_breakdown_sum
    FROM {{ ref('municipality_industry') }}
    GROUP BY survey_year, area
),

-- 都道府県側から外側結合する。内部結合にすると、ある都道府県の市区町村行が丸ごと
-- 消えたときにグループそのものが生まれず、0行 = 合格を返して素通りする。
by_prefecture AS (
    SELECT
        p.survey_year,
        p.area,
        p.establishments AS total,
        SUM(m.establishments) AS breakdown_sum,
        p.employees AS employee_total,
        SUM(m.employees) AS employee_breakdown_sum
    FROM {{ ref('municipality_industry') }} p
    LEFT JOIN {{ ref('municipality_industry') }} m
        ON m.survey_year = p.survey_year
        AND m.parent_area = p.area
        AND m.area_level = 'municipality'
        AND m.industry_code = '00'
    WHERE p.area_level = 'prefecture' AND p.industry_code = '00'
        AND NOT (p.survey_year = 2020 AND p.area = '20000')
    GROUP BY p.survey_year, p.area, p.establishments, p.employees
),

by_city AS (
    SELECT
        c.survey_year,
        c.area,
        c.establishments AS total,
        SUM(w.establishments) AS breakdown_sum,
        c.employees AS employee_total,
        SUM(w.employees) AS employee_breakdown_sum
    FROM {{ ref('municipality_industry') }} c
    JOIN {{ ref('municipality_industry') }} w
        ON w.survey_year = c.survey_year
        AND w.parent_area = c.area
        AND w.area_level = 'ward'
        AND w.industry_code = '00'
    WHERE c.area_level = 'municipality' AND c.industry_code = '00'
    GROUP BY c.survey_year, c.area, c.establishments, c.employees
)

SELECT '産業の区分が原典と違う' AS violation,
    CAST(survey_year AS VARCHAR) || ' ' || ARRAY_TO_STRING(category_codes, ',') AS detail
FROM by_year
WHERE category_codes <> LIST_SORT({{ industry_codes }}::VARCHAR[])
UNION ALL
SELECT '製造業計(00)の industry_level が1でない',
    CAST(survey_year AS VARCHAR) || ' ' || area
FROM {{ ref('municipality_industry') }}
WHERE industry_code = '00' AND industry_level IS DISTINCT FROM 1
UNION ALL
SELECT '中分類の industry_level が2でない',
    CAST(survey_year AS VARCHAR) || ' ' || area || ' ' || industry_code
FROM {{ ref('municipality_industry') }}
WHERE industry_code <> '00' AND industry_level IS DISTINCT FROM 2
UNION ALL
SELECT '中分類の行がある年に industry_level = 2 が無い', CAST(survey_year AS VARCHAR)
FROM (
    SELECT survey_year,
        COUNT(*) FILTER (WHERE industry_code <> '00') AS breakdown_rows,
        COUNT(*) FILTER (WHERE industry_level = 2) AS level2_rows
    FROM {{ ref('municipality_industry') }}
    GROUP BY survey_year
)
WHERE breakdown_rows <> level2_rows
UNION ALL
SELECT '製造業計 <> 中分類24区分の和（事業所数）', CAST(survey_year AS VARCHAR) || ' ' || area
FROM by_industry WHERE breakdown_rows > 0 AND total <> breakdown_sum
UNION ALL
SELECT '製造業計 <> 中分類24区分の和（従業者数）', CAST(survey_year AS VARCHAR) || ' ' || area
FROM by_industry WHERE breakdown_rows > 0 AND employee_total <> employee_breakdown_sum
UNION ALL
SELECT '都道府県に対応する市区町村の行が無い', CAST(survey_year AS VARCHAR) || ' ' || area
FROM by_prefecture WHERE breakdown_sum IS NULL
UNION ALL
SELECT '都道府県 <> 市区町村の和（事業所数）', CAST(survey_year AS VARCHAR) || ' ' || area
FROM by_prefecture WHERE total <> breakdown_sum
UNION ALL
SELECT '都道府県 <> 市区町村の和（従業者数）', CAST(survey_year AS VARCHAR) || ' ' || area
FROM by_prefecture WHERE employee_total <> employee_breakdown_sum
UNION ALL
SELECT '政令指定都市 <> 区の和（事業所数）', CAST(survey_year AS VARCHAR) || ' ' || area
FROM by_city WHERE total <> breakdown_sum
UNION ALL
SELECT '政令指定都市 <> 区の和（従業者数）', CAST(survey_year AS VARCHAR) || ' ' || area
FROM by_city WHERE employee_total <> employee_breakdown_sum
