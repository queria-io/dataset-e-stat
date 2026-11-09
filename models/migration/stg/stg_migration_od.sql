{# 参考表の地域の粒度を決め、値を整数にする。

   1 表は「表の主の地域」(転出先別なら前住地、転入元別なら現住地) ごとに、相手の地域を
   全国の総数・都道府県・市区町村・政令指定都市の区の順に並べる。相手の地域は、その年の
   移動者の総数が 10 人以上のものだけが個別に立ち、残りは「その他の県」「その他の市町村」
   「その他の区」にまとめられる (2017・2018・2024 年の表で確かめた。個別の行の総数の最小値が 10)。
   まとめの行も足すと、都道府県の和は総数に、市区町村の和は都道府県に一致する。
   raw_migration_od と同じ理由で view にする。 #}
{{ config(materialized='view') }}
SELECT
    year,
    table_kind,
    origin_code,
    origin_name,
    {{ migration_od_area_level('origin_code', 'origin_name', 'origin_meta_level') }} AS origin_level,
    NULLIF(origin_meta_parent, '00005') AS origin_parent,
    destination_code,
    destination_name,
    {{ migration_od_area_level('destination_code', 'destination_name', 'destination_meta_level') }}
        AS destination_level,
    NULLIF(destination_meta_parent, '00005') AS destination_parent,
    sex_code,
    sex,
    age_code,
    age,
    CASE WHEN year <= 2017 THEN '61000' ELSE '60000' END AS nationality_code,
    CASE WHEN year <= 2017 THEN '日本人移動者' ELSE '移動者' END AS nationality,
    CAST(value AS BIGINT) AS movers
FROM {{ ref('raw_migration_od') }}
