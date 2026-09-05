{# 令和2年国勢調査 従業地・通学地集計 第1-1-1表「男女，年齢（5歳階級），常住地又は
   従業地・通学地別人口」。分類は cat01=男女、cat02=年齢、cat03=常住地又は従業地・通学地。

   cat02 は取得時に cdCat02="00"(年齢総数)で絞っているが、絞り込みが効かなかった
   ときに年齢階級の行が mart に混ざり (area, cat01, cat03) が一意でなくなるため、
   ここでも総数だけに限る。

   cat03 は夜間人口(コードが 0 で始まる)と昼間人口(1 で始まる)が同じ列に縦に並び、
   さらにその内訳が level 2 / 3 に入る。level を無視して合計すると何重にも数える。
   コードの先頭 1 文字が夜間・昼間の別にあたるので population_base に出しておく。

   コードに R を含む 0R1「（再掲）流出人口」と 1R1「（再掲）流入人口」は level 2 に
   立つが、他の level 2 と並べて足せる区分ではない。どちらも他の区分の一部を足し直した
   再掲で、どこまでを地域の外とみなすかが area_level で変わる。市区町村（区・町村・
   政令指定都市以外の市）は 0031+0032+0033 と 101、政令指定都市と特別区部は
   0032+0033 と 1012+1013、都道府県は 0033 と 1013、全国は NULL。
   level だけでは見分けが付かないので is_reprint で分ける。 #}
SELECT
    area,
    area_metadata->>'$.name' AS area_name,
    {{ e_stat_municipality_area_level('area_metadata') }} AS area_level,
    area_metadata->>'$.parent_code' AS parent_area,
    cat01,
    cat01_metadata->>'$.name' AS sex,
    cat03,
    cat03_metadata->>'$.name' AS location,
    TRY_CAST(cat03_metadata->>'$.level' AS INTEGER) AS location_level,
    CASE LEFT(cat03, 1)
        WHEN '0' THEN 'nighttime'
        WHEN '1' THEN 'daytime'
    END AS population_base,
    cat03 LIKE '%R%' AS is_reprint,
    unit,
    TRY_CAST(value AS BIGINT) AS value
FROM {{ ref('raw_census_municipality_daytime_population') }}
WHERE cat02 = '00'
