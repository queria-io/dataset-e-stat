{{ config(materialized='ephemeral') }}

-- 今の都道府県と市区町村の一覧。ビルドの中で、統計表の地域名に標準地域コードを当てるときに使う。
-- 公開せず、読む側の mart に展開する。
--
-- code.municipality_name の今も有効な行 (valid_to が NULL) に、都道府県の行 (XX000) を加える。
-- 行政区の municipality_code は所属する政令指定都市のコード、市区町村と政令指定都市は自分自身。
-- 東京都の特別区部 (13100、district) は集計の行なので、市区町村に数えず municipality_code も持たない。
WITH current_area AS (
    SELECT area_code, pref_code, pref_name, parent_name, name, area_kind
    FROM {{ ref('municipality_name') }}
    WHERE valid_to IS NULL
)

SELECT
    pref_code || '000' AS area_code,
    pref_code,
    pref_name,
    pref_name AS name,
    'prefecture' AS area_kind,
    false AS is_municipality,
    NULL AS municipality_code
FROM current_area
GROUP BY pref_code, pref_name

UNION ALL

SELECT
    a.area_code,
    a.pref_code,
    a.pref_name,
    a.name,
    a.area_kind,
    a.area_kind IN ('municipality', 'designated_city') AS is_municipality,
    CASE
        WHEN a.area_kind = 'ward' THEN c.area_code
        WHEN a.area_kind IN ('municipality', 'designated_city') THEN a.area_code
    END AS municipality_code
FROM current_area a
LEFT JOIN current_area c
    ON a.area_kind = 'ward'
    AND c.area_kind = 'designated_city'
    AND c.pref_code = a.pref_code
    AND c.name = a.parent_name
