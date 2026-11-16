-- population の合計が粒度と住民区分をまたいで整合することを検証する。
-- 結果が0行ならテスト成功。
--
-- 元データは年次で見出しの構成が5通りに揺れ、列の対応づけが1つずれても
-- 行数と型は変わらないまま値だけが入れ替わる。全国計・都道府県・市区町村の
-- 3粒度と、総計・日本人住民・外国人住民の3区分は互いに合計が一致するので、
-- そこが崩れていないことで対応づけを担保する。

-- 都道府県の合算が全国計と合わない
SELECT
    'prefecture_sum' AS violation,
    n.year,
    n.resident_kind,
    n.population_total AS expected,
    p.population_total AS actual
FROM (
    SELECT year, resident_kind, population_total
    FROM {{ ref('population') }}
    WHERE area_level = 'national'
) n
JOIN (
    SELECT year, resident_kind, SUM(population_total) AS population_total
    FROM {{ ref('population') }}
    WHERE area_level = 'prefecture'
    GROUP BY year, resident_kind
) p USING (year, resident_kind)
WHERE n.population_total IS DISTINCT FROM p.population_total

UNION ALL

-- 総計が日本人住民と外国人住民の和と合わない（3区分に分かれる2013年以降）
SELECT
    'resident_kind_sum',
    year,
    'total',
    MAX(population_total) FILTER (WHERE resident_kind = 'total'),
    SUM(population_total) FILTER (WHERE resident_kind <> 'total')
FROM {{ ref('population') }}
WHERE year >= 2013 AND area_level = 'national'
GROUP BY year
HAVING MAX(population_total) FILTER (WHERE resident_kind = 'total')
    IS DISTINCT FROM SUM(population_total) FILTER (WHERE resident_kind <> 'total')

UNION ALL

-- 最新年で、市区町村として数える行の合算が全国計と合わない。
-- area_code から current_area を引く経路が生きていることの担保でもある。
-- 過去年は合併で消滅したコードが現行一覧に無く引けないので、最新年だけ見る。
SELECT
    'municipality_sum',
    n.year,
    n.resident_kind,
    n.population_total,
    m.population_total
FROM (
    SELECT year, resident_kind, population_total
    FROM {{ ref('population') }}
    WHERE area_level = 'national'
        AND year = (SELECT MAX(year) FROM {{ ref('population') }})
) n
JOIN (
    SELECT p.year, p.resident_kind, SUM(p.population_total) AS population_total
    FROM {{ ref('population') }} p
    JOIN {{ ref('current_area') }} c ON c.area_code = p.area_code
    WHERE p.area_level = 'municipality'
        AND c.is_municipality
        AND p.year = (SELECT MAX(year) FROM {{ ref('population') }})
    GROUP BY p.year, p.resident_kind
) m USING (year, resident_kind)
WHERE n.population_total IS DISTINCT FROM m.population_total
