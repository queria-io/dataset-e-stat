{# 空き家数 (tab=03-2023) を、地域の粒度と各軸の名前を付けて取り出す。

   地域のメタ情報の level の振り方は年収階級別主世帯数の表と同じで、経済センサスの産業横断的
   集計と同じ e_stat_economic_census_area_level で分ける。市町村の行は全市と一部の町村だけで、
   都道府県の全域は覆わない。
   各軸は先頭が 0 総数で、内訳と同じ列に並ぶ。原典の「-」は value が NULL で入る。 #}
SELECT
    area,
    area_metadata->>'$.name' AS area_name,
    {{ e_stat_economic_census_area_level('area', 'area_metadata') }} AS area_level,
    area_metadata->>'$.parent_code' AS parent_area,
    cat04 AS vacancy_type_code,
    cat04_metadata->>'$.name' AS vacancy_type,
    cat01 AS decay_code,
    cat01_metadata->>'$.name' AS decay,
    cat02 AS building_type_code,
    cat02_metadata->>'$.name' AS building_type,
    cat03 AS structure_code,
    cat03_metadata->>'$.name' AS structure,
    TRY_CAST(value AS DOUBLE) AS vacant_homes
FROM {{ ref('raw_housing_survey_vacant_homes') }}
WHERE tab = '03-2023'
