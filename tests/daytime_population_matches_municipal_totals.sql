-- メッシュ昼間人口を市区町村ごとに合計すると公表昼間人口に一致することを検証する。
-- mesh_daytime_population は市区町村の公表値をメッシュへ按分しているので、
-- ウェイトの正規化が壊れていない限り合計は必ず一致する。按分の分母を取り違える、
-- 市区町村の割り当てが重複する、といった壊れ方はここで落ちる。
--
-- 許容誤差はメッシュ単位の整数丸めの分だけ。mart で1メッシュあたり最大0.5人ずれ、
-- 市区町村あたりのメッシュ数だけ積み上がる。丸める前の値は実測で誤差0.0だった。
WITH estimated AS (
    SELECT
        city_code,
        SUM(daytime_population) AS estimated,
        COUNT(*) AS meshes
    FROM {{ ref('daytime_population_mesh_1km') }}
    WHERE city_code IS NOT NULL
    GROUP BY city_code
),

official AS (
    SELECT
        area AS city_code,
        MAX(CASE WHEN cat01 = 'A6107' THEN value END) AS official
    FROM {{ ref('stg_municipal_population') }}
    WHERE year = 2020 AND cat01 = 'A6107'
    GROUP BY area
)

SELECT
    e.city_code,
    e.meshes,
    e.estimated,
    o.official
FROM estimated AS e
INNER JOIN official AS o ON e.city_code = o.city_code
WHERE ABS(e.estimated - o.official) > e.meshes * 0.5 + 1
