{# 都道府県別の男女別人口 (千人) を、地域 × 男女 × 人口の種類 × 年の1行にする。

   地域は全国 (00000) と47都道府県が同じ列に並ぶ。男女は計 (000) と男 (001)・女 (002)、
   人口の種類は総人口 (001) と日本人人口 (002) で、どちらも計と内訳が同じ軸にある。
   2005・2010・2015年は国勢調査の年で time が 'XXXX000001'、2020年以降は推計で 'XXXX000000'。
   年は time の先頭4桁から切り出す。値は千人で、千人未満を丸めてある。 #}
SELECT
    area,
    area_metadata->>'$.name' AS area_name,
    CASE WHEN area = '00000' THEN 'national' ELSE 'prefecture' END AS area_level,
    cat01 AS sex_code,
    cat01_metadata->>'$.name' AS sex,
    cat02 AS population_type_code,
    cat02_metadata->>'$.name' AS population_type,
    time,
    TRY_CAST(SUBSTR(time, 1, 4) AS INTEGER) AS year,
    TRY_CAST(value AS BIGINT) AS population
FROM {{ ref('raw_population_estimates_prefecture') }}
WHERE tab = '001'
