-- 原典の行見出し (「全国計」と都道府県名) を標準地域コードに当てる。
-- 都道府県名は原典も code.municipality も正式名 (北海道・東京都・大阪府 など) なので、名前で当てる。
WITH labels AS (
    SELECT DISTINCT prefecture_name FROM {{ ref('raw_energy_consumption_industry') }}
    UNION
    SELECT DISTINCT prefecture_name FROM {{ ref('raw_energy_consumption_energy_type') }}
),

prefecture AS (
    SELECT pref_code, pref_name
    FROM {{ ref('stg_municipality') }}
    WHERE is_prefecture
)

SELECT
    l.prefecture_name AS label,
    CASE WHEN l.prefecture_name = '全国計' THEN '00000' ELSE p.pref_code || '000' END AS area,
    CASE WHEN l.prefecture_name = '全国計' THEN '全国' ELSE p.pref_name END AS area_name,
    p.pref_code AS prefecture_code
FROM labels l
LEFT JOIN prefecture p ON p.pref_name = l.prefecture_name
