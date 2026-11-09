-- 参考表の転出先別 (municipality_migration_destination) と転入元別
-- (municipality_migration_origin) が、原典の集計構造どおりに読めていることを検証する。
-- 結果が0行ならテスト成功。
--
-- 前住地と現住地のどちらが cat01 に入るかは表ごとに書いている (migration_od_sources)。
-- 向きを取り違えると、行数も値もそのままで前住地と現住地が入れ替わる。足し算で押さえる。
--
-- 1) 相手の地域の階層が足し上がる。都道府県 + その他の県 = 総数、市区町村 + その他の
--    市町村 = 都道府県、区 + その他の区 = 政令指定都市・東京都特別区部。年齢・男女の
--    区分ごとに成り立つ (2024年の転出先別で1のずれも無い、実測)。
-- 2) 相手の地域の総数が municipality_migration の転出者数 (転出先別) または転入者数
--    (転入元別) と一致する (2017・2018・2024年の5地域で実測)。向きを取り違えると、
--    転出者数と転入者数が入れ替わってここで落ちる。
-- 3) 表の主の地域が毎年そろう。都道府県47と、区のある政令指定都市・東京都特別区部の
--    区の和が市に一致する。
-- 4) 粒度がどの行にも付く。原典が名称や level を変えると NULL になる。

-- 元表が揃っていないカタログ (手元で取り込む前) では検査しない。0 行の表を検査して落とすと
-- 他のテーブルの更新まで止まるため。
{% if migration_od_sources_loaded() %}
{% set tables = [
    ('municipality_migration_destination', 'origin', 'destination', 'outflow'),
    ('municipality_migration_origin', 'destination', 'origin', 'inflow'),
] %}
{% for model, subj, other, measure in tables %}
{% if not loop.first %}UNION ALL{% endif %}
(
WITH t AS (
    SELECT year, {{ subj }}_code AS subj, {{ subj }}_level AS subj_level,
        {{ subj }}_parent AS subj_parent,
        {{ other }}_code AS code, {{ other }}_level AS level, {{ other }}_parent AS parent,
        sex_code, age_code, nationality_code, movers
    FROM {{ ref(model) }}
),

-- 1) 相手の地域の階層
children AS (
    SELECT year, subj, sex_code, age_code,
        CASE WHEN level IN ('prefecture', 'other_prefectures') THEN '00005' ELSE parent END AS up,
        SUM(movers) AS s
    FROM t
    WHERE level IN ('prefecture', 'other_prefectures', 'municipality', 'other_municipalities',
        'ward', 'other_wards')
    GROUP BY ALL
),

hierarchy AS (
    SELECT '{{ model }}: 相手の地域の内訳が上位に足し上がらない' AS failure,
        c.year, c.subj AS area, c.up AS detail, c.s AS got, p.movers AS expected
    FROM children c
    LEFT JOIN t p ON p.year = c.year AND p.subj = c.subj AND p.sex_code = c.sex_code
        AND p.age_code = c.age_code AND p.code = c.up
    WHERE COALESCE(p.movers, -1) <> c.s
),

-- 2) 総数が municipality_migration と一致する
totals AS (
    SELECT '{{ model }}: 総数が municipality_migration の {{ measure }} と違う' AS failure,
        t.year, t.subj AS area, t.sex_code AS detail, t.movers AS got, m.{{ measure }} AS expected
    FROM t
    LEFT JOIN {{ ref('municipality_migration') }} m
        ON m.year = t.year AND m.area = t.subj AND m.sex_code = t.sex_code
        AND m.nationality_code = t.nationality_code
    WHERE t.code = '00005' AND t.age_code = '000'
        AND COALESCE(m.{{ measure }}, -1) <> t.movers
),

-- 3) 表の主の地域
subjects AS (
    SELECT year,
        COUNT(DISTINCT subj) FILTER (WHERE subj_level = 'prefecture') AS prefectures,
        COUNT(DISTINCT subj) FILTER (WHERE subj_level = 'ward') AS wards
    FROM t
    GROUP BY year
),

coverage AS (
    SELECT '{{ model }}: 表の主の地域が欠けている' AS failure,
        year, NULL AS area, CAST(wards AS VARCHAR) AS detail, prefectures AS got, 47 AS expected
    FROM subjects
    WHERE prefectures <> 47 OR wards < 190
),

ward_sum AS (
    SELECT year, subj_parent AS city, sex_code, age_code, SUM(movers) AS s
    FROM t
    WHERE subj_level = 'ward' AND code = '00005'
    GROUP BY ALL
),

wards AS (
    SELECT '{{ model }}: 表の主の区の和が市と違う' AS failure,
        w.year, w.city AS area, w.age_code AS detail, w.s AS got, c.movers AS expected
    FROM ward_sum w
    LEFT JOIN t c ON c.year = w.year AND c.subj = w.city AND c.code = '00005'
        AND c.sex_code = w.sex_code AND c.age_code = w.age_code
    WHERE COALESCE(c.movers, -1) <> w.s
),

-- 4) 粒度
levels AS (
    SELECT '{{ model }}: 粒度が決まらない地域がある' AS failure,
        year, subj AS area, code AS detail, NULL AS got, NULL AS expected
    FROM t
    WHERE subj_level IS NULL OR level IS NULL
)

SELECT * FROM hierarchy
UNION ALL SELECT * FROM totals
UNION ALL SELECT * FROM coverage
UNION ALL SELECT * FROM wards
UNION ALL SELECT * FROM levels
)
{% endfor %}
{% else %}
SELECT NULL AS failure WHERE FALSE
{% endif %}
