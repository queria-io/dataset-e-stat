{# 令和2年国勢調査 従業地・通学地集計 第6-1表「従業・通学市区町村，男女別通勤者・
   通学者数」。area=常住地、cat02=従業・通学地、cat01=男女。1 行が「常住地 → 従業・
   通学地」1 組にあたる OD (起終点) 行列。

   cat02 は取得時に lvCat02="1-2" で「総数」と都道府県 (と「不詳・外国」「不詳」) に
   絞っている。絞り込みが効かなかったときは市区町村 1,917 区分が入って行数が 40 倍に
   なり、しかも大半が値の無い空セルなので、ここでも level 1-2 だけに限る。

   cat02 の 99998「従業・通学市区町村「不詳・外国」」と 99999「従業地・通学地「不詳」」は
   level 2 に立つが都道府県ではない。level だけで都道府県を選ぶとこの 2 区分が混ざるので
   destination_area_level で分ける。47 都道府県とこの 2 区分の和が「総数」に一致する。 #}
SELECT
    area,
    area_metadata->>'$.name' AS area_name,
    {{ e_stat_municipality_area_level('area_metadata') }} AS area_level,
    area_metadata->>'$.parent_code' AS parent_area,
    cat02 AS destination_area,
    cat02_metadata->>'$.name' AS destination_area_name,
    CASE
        WHEN cat02 = '00000' THEN 'total'
        WHEN cat02 IN ('99998', '99999') THEN 'unknown'
        ELSE 'prefecture'
    END AS destination_area_level,
    cat01,
    cat01_metadata->>'$.name' AS sex,
    unit,
    TRY_CAST(value AS BIGINT) AS value
FROM {{ ref('raw_census_commuting_flow') }}
WHERE (cat02_metadata->>'$.level') IN ('1', '2')
