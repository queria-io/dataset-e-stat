-- 250mメッシュ境界は mesh_1km の各区画を 16 に分けたもの。
-- 各区画が、9桁目・10桁目 (1=南西 2=南東 3=北西 4=北東) の示す位置に
-- 250m 四方の大きさで置かれていなければ落とす。
-- コードから座標を出す計算の誤り、9桁目と10桁目の取り違え、位置の重複を拾う。
WITH expected(digit, dx, dy) AS (
    VALUES (1, 0, 0), (2, 1, 0), (3, 0, 1), (4, 1, 1)
),

cells AS (
    SELECT
        m.mesh_code,
        m.mesh_1km_code,
        (ST_XMin(m.geometry) - ST_XMin(b.geometry)) * 320 AS x0,
        (ST_YMin(m.geometry) - ST_YMin(b.geometry)) * 480 AS y0,
        (ST_XMax(m.geometry) - ST_XMin(b.geometry)) * 320 AS x1,
        (ST_YMax(m.geometry) - ST_YMin(b.geometry)) * 480 AS y1,
        h.dx * 2 + q.dx AS x,
        h.dy * 2 + q.dy AS y
    FROM {{ ref('mesh_250m') }} AS m
    INNER JOIN {{ ref('mesh_1km') }} AS b ON b.mesh_code = m.mesh_1km_code
    INNER JOIN expected AS h ON h.digit = CAST(SUBSTR(m.mesh_code, 9, 1) AS INTEGER)
    INNER JOIN expected AS q ON q.digit = CAST(SUBSTR(m.mesh_code, 10, 1) AS INTEGER)
)

SELECT mesh_code
FROM cells
WHERE ABS(x0 - x) > 1e-5
    OR ABS(y0 - y) > 1e-5
    OR ABS(x1 - (x + 1)) > 1e-5
    OR ABS(y1 - (y + 1)) > 1e-5

UNION ALL

-- 1kmメッシュごとに 16 区画がそろっていること (9桁目・10桁目が 1〜4 以外の区画も落ちる)
SELECT b.mesh_code
FROM {{ ref('mesh_1km') }} AS b
LEFT JOIN cells AS c ON c.mesh_1km_code = b.mesh_code
GROUP BY b.mesh_code
HAVING COUNT(DISTINCT c.mesh_code) <> 16
