{# 1kmメッシュを市区町村へ割り当てる。

   メッシュ統計には市区町村コードが付かないので、メッシュの中心点を含む
   町丁・字等ポリゴンの市区町村を採る。中心点はメッシュコードから算術で出せるので
   メッシュ側のジオメトリは要らない。

   標準地域メッシュ(JIS X 0410)のコードは 8 桁で、上位から
   p(2桁) u(2桁) q(1桁) v(1桁) r(1桁) w(1桁)。区画の南西端は
     緯度 = (p + (q + r/10) / 8) / 1.5
     経度 = 100 + u + (v + w/10) / 8
   で、区画の大きさは緯度 1/120 度・経度 1/80 度。中心は南西端から
   その半分ずらすので、q/v の係数側に 0.05 (= 0.5/10) を足す。

   境界をまたぐメッシュは中心点のある市区町村へ丸ごと入る。按分のウェイトは
   市区町村内で正規化するので、この割り当ての粗さは市区町村合計が公表昼間人口と
   一致することには影響しない (効くのはメッシュ間の分布だけ)。

   small_area は 9桁(字)と11桁(丁目)が排他タイルなので両方を対象にする。
   同じ点が複数タイルに載っても市区町村は同じなので MIN で1つに畳む。 #}
{{ config(materialized='ephemeral') }}

WITH target AS (
    SELECT DISTINCT mesh_code FROM {{ ref('stg_mesh_population') }}
    UNION
    SELECT DISTINCT mesh_code FROM {{ ref('stg_mesh_establishment') }}
),

centroid AS (
    SELECT
        mesh_code,
        ST_Point(
            100 + CAST(SUBSTR(mesh_code, 3, 2) AS INTEGER)
            + (
                CAST(SUBSTR(mesh_code, 6, 1) AS INTEGER)
                + CAST(SUBSTR(mesh_code, 8, 1) AS INTEGER) / 10.0
                + 0.05
            ) / 8.0,
            (
                CAST(SUBSTR(mesh_code, 1, 2) AS INTEGER)
                + (
                    CAST(SUBSTR(mesh_code, 5, 1) AS INTEGER)
                    + CAST(SUBSTR(mesh_code, 7, 1) AS INTEGER) / 10.0
                    + 0.05
                ) / 8.0
            ) / 1.5
        ) AS point
    FROM target
)

SELECT
    c.mesh_code,
    MIN(s.prefecture_code || s.city_code) AS city_code
FROM centroid AS c
INNER JOIN {{ ref('small_area') }} AS s
    ON ST_Intersects(s.geometry, c.point)
WHERE LENGTH(s.key_code) IN (9, 11)
GROUP BY c.mesh_code
