-- 市町村別の表の行見出し (都道府県のシート名と、その中の 3 桁のコード・名前) を
-- 標準地域コードに当てる。
--
-- 都道府県コードはシート名 (都道府県の正式名) で code.municipality から引き、3 桁の
-- コードを後ろに付けて 5 桁の地域コードにする。都道府県の計の行は XX000。
-- 政令指定都市は区の行だけで市の行が無い。区から市に足し上げられるよう、
-- code.municipality の municipality_code (区の行は市のコード) を city_code に持つ。
--
-- 次の行は現行の code.municipality に無い。
-- - 「東京都外」(東京都 999)・「大阪市外」(大阪府 129): 標準地域コードではないので area は NULL
-- - 浜松市の旧区 (22131〜22137): 2024年1月の区の再編で無くなった区。area は原典のまま持ち、
--   city_code は浜松市 (22130) にする
WITH labels AS (
    {% for t in ['schools', 'students', 'teachers'] %}
    SELECT DISTINCT prefecture_name, municipality_code, municipality_name
    FROM {{ ref('raw_school_municipality_' ~ t) }}
    {{ 'UNION' if not loop.last }}
    {% endfor %}
),

coded AS (
    SELECT
        l.prefecture_name,
        l.municipality_code,
        l.municipality_name,
        p.pref_code AS prefecture_code,
        p.pref_code || coalesce(l.municipality_code, '000') AS code5,
        l.municipality_name IN ('東京都外', '大阪市外') AS is_outside
    FROM labels l
    LEFT JOIN {{ ref('municipality') }} p
        ON p.is_prefecture AND p.pref_name = l.prefecture_name
)

SELECT
    c.prefecture_name,
    c.municipality_code,
    c.municipality_name,
    c.prefecture_code,
    CASE WHEN NOT c.is_outside THEN c.code5 END AS area,
    coalesce(c.municipality_name, c.prefecture_name) AS area_name,
    CASE
        WHEN c.municipality_code IS NULL THEN 'prefecture'
        WHEN c.is_outside THEN 'outside'
        WHEN m.area_kind = 'ward' OR c.code5 BETWEEN '22131' AND '22137' THEN 'ward'
        ELSE 'municipality'
    END AS area_level,
    CASE
        WHEN c.code5 BETWEEN '22131' AND '22137' THEN '22130'
        WHEN c.municipality_code IS NOT NULL AND NOT c.is_outside THEN m.municipality_code
    END AS city_code
FROM coded c
LEFT JOIN {{ ref('municipality') }} m ON m.area_code = c.code5
