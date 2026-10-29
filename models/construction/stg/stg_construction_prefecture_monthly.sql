{# 建設総合統計の月別《地域別》出来高を都道府県の行だけにする。

   地域軸は9つの地方（level=2）と都道府県（level=3）の2段で、北海道だけは都道府県の
   行が無く「北海道地方」（00042）の1行しかない。00042 を北海道（01000）として都道府県に
   数え、残りの地方の行は落とす。地方の値は都道府県の和を億円で丸め直したもので、
   都道府県の和と最大2億円ずれる。
   地方の区分は統計独自のもので、山梨県・長野県が関東地方、新潟県が北陸地方に入り、
   中部地方（51000）は岐阜・静岡・愛知・三重の4県。所属は都道府県の行の parent_code に
   あるので region_code として残す。 #}
WITH source AS (
    SELECT area, area_metadata, time, time_metadata, value
    FROM {{ ref('raw_construction_prefecture_monthly') }}
    WHERE tab = '100'
),

regions AS (
    SELECT DISTINCT area AS region_code, area_metadata->>'$.name' AS region_name
    FROM source
    WHERE area_metadata->>'$.level' = '2'
),

prefectures AS (
    SELECT
        CASE WHEN area = '00042' THEN '01000' ELSE area END AS area,
        CASE WHEN area = '00042' THEN '北海道' ELSE area_metadata->>'$.name' END AS area_name,
        CASE WHEN area = '00042' THEN '00042' ELSE area_metadata->>'$.parent_code' END AS region_code,
        time,
        time_metadata->>'$.name' AS time_name,
        value
    FROM source
    WHERE area_metadata->>'$.level' = '3' OR area = '00042'
)

SELECT
    SUBSTR(p.area, 1, 2) AS prefecture_code,
    p.area,
    p.area_name,
    p.region_code,
    r.region_name,
    p.time,
    p.time_name,
    TRY_CAST(SUBSTR(p.time, 1, 4) AS INTEGER) AS year,
    TRY_CAST(SUBSTR(p.time, 9, 2) AS INTEGER) AS month,
    CAST(p.value AS BIGINT) AS output
FROM prefectures p
LEFT JOIN regions r USING (region_code)
