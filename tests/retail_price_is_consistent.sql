-- retail_price の mart が、原典の構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 品目は cat02（銘柄）にあり、cat01 と tab は1値しか無いので stg で落としている。
-- e-Stat 側が軸を増やすと、落とした軸の分だけ (品目, 市, 年) が一意でなくなり、
-- 列の見た目も行数の桁も変わらないまま値が複製される。一意性がその検査になる。
--
-- 単位は unit 列を信じられない。火災・地震保険料の5品目は保険料率（割合）なのに
-- 全行「円」が入る（実測: 3182/3183/3184 と、2025年から割合になった 3186/3187）。
-- 見分けられるのは品目名の【表章単位：割合】だけなので、その注記を持つ品目を
-- 名指しし、増減したら落とす。増えた年はここが赤くなるので、値を見てから足す。
--
-- 価格が負になるのは電気代の燃料費調整単価の2品目だけ（実測: 3505/3506。
-- 2015年1月に 3511 電気代へ統合されて以降は現れない）。それ以外の負値は
-- 列のずれか符号の取り違えなので落とす。0 は無償化の品目にあるので通す。
--
-- 値そのものは片側だけ見ても守れない。value はローダーが float に直す時点で、
-- 読めない表記をすべて None に倒す。原典が表記を変えただけで、行数も年も市も
-- 正しいまま値だけ全部 NULL になり、負値や一意性の検査は素通りする。年ごとの
-- 非 NULL の割合で下から押さえる（実測: 76.3%〜80.8%。調査していない品目×市の
-- 組合せが常に2割ほどあるので、NOT NULL は使えない）。
--
-- 地域コードは5桁の標準地域コードそのもので、95コード中88が現行の
-- code.municipality に載る（実測）。載らない7つは政令指定都市へ移行する前の
-- 市のコードで、名称の注記に有効期間が入っている。この対応が崩れると、
-- 地域コードを鍵にした結合が黙って行を落とす。

{% set known_ratio_items = ['03182', '03183', '03184', '03186', '03187'] %}
{% set known_negative_items = ['03505', '03506'] %}
{% set known_historical_areas = [
    '11204', '11244', '15201', '22201', '22202', '33201', '43201'
] %}

WITH expected_years AS (
    SELECT UNNEST(RANGE(2000, (SELECT MAX(year) FROM {{ ref('item_price') }}) + 1))
        AS year
),

ratio_items AS (
    SELECT DISTINCT cat02 FROM {{ ref('item_price') }}
    WHERE item_note LIKE '%表章単位%'
),

known_ratio_items AS (
    SELECT * FROM (VALUES
        {%- for code in known_ratio_items %}
        ('{{ code }}'){{ "," if not loop.last }}
        {%- endfor %}
    ) AS t(cat02)
),

negative_items AS (
    SELECT DISTINCT cat02 FROM {{ ref('item_price') }} WHERE value < 0
),

known_negative_items AS (
    SELECT * FROM (VALUES
        {%- for code in known_negative_items %}
        ('{{ code }}'){{ "," if not loop.last }}
        {%- endfor %}
    ) AS t(cat02)
),

-- EXCEPT は UNION ALL と同じ優先順位で左から結合するので、下の並びに直接
-- 書くとそれまでの検査結果ごと引かれる。CTE に閉じ込める。
unexpected_ratio_items AS (
    SELECT * FROM ratio_items EXCEPT ALL SELECT * FROM known_ratio_items
),

vanished_ratio_items AS (
    SELECT * FROM known_ratio_items EXCEPT ALL SELECT * FROM ratio_items
),

unexpected_negative_items AS (
    SELECT * FROM negative_items EXCEPT ALL SELECT * FROM known_negative_items
),

unresolved_areas AS (
    SELECT DISTINCT p.area
    FROM {{ ref('item_price') }} p
    LEFT JOIN {{ ref('municipality') }} m ON m.area_code = p.area
    WHERE m.area_code IS NULL
),

known_historical_areas AS (
    SELECT * FROM (VALUES
        {%- for code in known_historical_areas %}
        ('{{ code }}'){{ "," if not loop.last }}
        {%- endfor %}
    ) AS t(area)
),

unexpected_unresolved_areas AS (
    SELECT * FROM unresolved_areas EXCEPT ALL SELECT * FROM known_historical_areas
),

resolved_historical_areas AS (
    SELECT * FROM known_historical_areas EXCEPT ALL SELECT * FROM unresolved_areas
)

SELECT '年平均価格の行が無い、または収録が2000年から始まっていない' AS violation,
    COALESCE(CAST(min_year AS VARCHAR), 'empty') AS detail
FROM (
    SELECT COUNT(*) AS rows, MIN(year) AS min_year FROM {{ ref('item_price') }}
)
WHERE rows = 0 OR min_year <> 2000

UNION ALL

SELECT '収録されていない年がある', CAST(e.year AS VARCHAR)
FROM expected_years e
LEFT JOIN (SELECT DISTINCT year FROM {{ ref('item_price') }}) y USING (year)
WHERE y.year IS NULL

UNION ALL

SELECT '品目×市×年が一意でない', cat02 || ' ' || area || ' ' || CAST(year AS VARCHAR)
FROM {{ ref('item_price') }}
GROUP BY cat02, area, year
HAVING COUNT(*) > 1

UNION ALL

-- 県庁所在市はどの年もすべての都道府県にあるので、47そろわない年は市が丸ごと
-- 落ちている。市の数そのものは調査市の入れ替えで年ごとに動くので見ない。
SELECT '都道府県が47そろわない年がある',
    CAST(year AS VARCHAR) || ' ' || CAST(COUNT(DISTINCT LEFT(area, 2)) AS VARCHAR)
FROM {{ ref('item_price') }}
GROUP BY year
HAVING COUNT(DISTINCT LEFT(area, 2)) <> 47

UNION ALL

SELECT '地域コードが5桁の標準地域コードの形をしていない', area
FROM (SELECT DISTINCT area FROM {{ ref('item_price') }})
WHERE NOT regexp_matches(area, '^[0-4][0-9][0-9]{3}$')

UNION ALL

SELECT '円単位でない品目が既知の5つ以外にある', cat02
FROM unexpected_ratio_items

UNION ALL

SELECT '既知の円単位でない品目が消えている（名指しを外す）', cat02
FROM vanished_ratio_items

UNION ALL

SELECT '価格が負の品目が既知の2つ以外にある', cat02
FROM unexpected_negative_items

UNION ALL

SELECT '標準地域コードに無い地域コードが既知の7つ以外にある', area
FROM unexpected_unresolved_areas

UNION ALL

SELECT '既知の旧コードが標準地域コードに現れている（名指しを外す）', area
FROM resolved_historical_areas

UNION ALL

SELECT '年の非 NULL の割合が5割を切っている',
    CAST(year AS VARCHAR) || ' ' || CAST(ROUND(100.0 * COUNT(value) / COUNT(*), 1) AS VARCHAR) || '%'
FROM {{ ref('item_price') }}
GROUP BY year
HAVING COUNT(value) * 2 < COUNT(*)
