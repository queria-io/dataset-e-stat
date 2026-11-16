-- 今の都道府県・市区町村の一覧 (current_area) が、統計表の地域名に当てるのに使える形になっている
-- - 標準地域コード 1 つに 1 行
-- - 都道府県は 47
-- - 行政区はすべて所属する政令指定都市のコードを持つ
SELECT 'duplicate_area_code' AS violation, area_code AS detail
FROM {{ ref('current_area') }}
GROUP BY area_code
HAVING count(*) > 1

UNION ALL

SELECT 'prefecture_count', CAST(count(*) AS VARCHAR)
FROM {{ ref('current_area') }}
WHERE area_kind = 'prefecture'
HAVING count(*) <> 47

UNION ALL

SELECT 'ward_without_city', area_code
FROM {{ ref('current_area') }}
WHERE area_kind = 'ward' AND municipality_code IS NULL
