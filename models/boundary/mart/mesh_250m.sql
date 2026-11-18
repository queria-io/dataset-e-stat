{# 250mメッシュ（4分の1地域メッシュ）の区画。
   統計GIS の250mメッシュ境界は、1kmメッシュ境界にある区画をそれぞれ16に分けたものと区画も座標も同じ。
   ダウンロードせずに mesh_1km から JIS X 0410 の規則で作る。
   全国で約800万行あり、毎日の CI で複製しないよう view にする。
   4分の1地域メッシュの位置: 9桁目と10桁目とも 1=南西 2=南東 3=北西 4=北東。 #}
{{ config(materialized='view') }}

WITH quarter(digit, dx, dy) AS (
    VALUES (1, 0, 0), (2, 1, 0), (3, 0, 1), (4, 1, 1)
),

mesh AS (
    SELECT
        b.mesh_code AS mesh_1km_code,
        b.mesh1_code,
        -- 3次メッシュの南西端。緯度は 1次 40分・2次 5分・3次 30秒、経度は 1次 1度・2次 7分30秒・3次 45秒
        CAST(SUBSTR(b.mesh_code, 1, 2) AS INTEGER) / 1.5
            + CAST(SUBSTR(b.mesh_code, 5, 1) AS INTEGER) / 12.0
            + CAST(SUBSTR(b.mesh_code, 7, 1) AS INTEGER) / 120.0 AS south,
        100 + CAST(SUBSTR(b.mesh_code, 3, 2) AS INTEGER)
            + CAST(SUBSTR(b.mesh_code, 6, 1) AS INTEGER) / 8.0
            + CAST(SUBSTR(b.mesh_code, 8, 1) AS INTEGER) / 80.0 AS west,
        h.digit AS half_digit,
        q.digit AS quarter_digit,
        -- 250mメッシュは緯度 7.5秒 (1/480度)・経度 11.25秒 (1/320度)
        h.dx * 2 + q.dx AS x,
        h.dy * 2 + q.dy AS y
    FROM {{ ref('mesh_1km') }} AS b
    CROSS JOIN quarter AS h
    CROSS JOIN quarter AS q
)

SELECT
    mesh_1km_code || half_digit || quarter_digit AS mesh_code,
    mesh_1km_code,
    mesh1_code,
    CAST(half_digit AS VARCHAR) AS mesh4_code,
    CAST(quarter_digit AS VARCHAR) AS mesh5_code,
    -- mesh_1km と同じく JGD2000 の緯度経度
    ST_SetCRS(
        ST_MakeEnvelope(
            west + x / 320.0,
            south + y / 480.0,
            west + (x + 1) / 320.0,
            south + (y + 1) / 480.0
        ),
        'EPSG:4612'
    ) AS geometry
FROM mesh
