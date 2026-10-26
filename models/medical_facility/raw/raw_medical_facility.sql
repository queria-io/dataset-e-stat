{# 医療施設調査「病院数；病床数，病院－病床の種類・二次医療圏・市区町村別」と
   「一般診療所数；歯科診療所数；病床数，病床の有無・二次医療圏・市区町村別」を年ごとに
   1 表ずつ取り込んだ元表 (load_local.py の medical_facility) を縦に積む。

   地域と項目のどちらが cat01 に入るかは年で違う (2014 年だけ地域が cat01)。地域の
   名称は「01202 函館市」のようにコードを前置するので、名称が数字で始まる軸を地域とみる。
   年と表の種類は統計表そのものが表すので、元表の名前から付ける。
   地域の並び (area_order) は取得時に残したメタ情報の順。二次医療圏の所属を読むのに使う。
   2013 年の表は取り込んでいない (local_tables.yml)。
   元表が揃っていないカタログ (手元で取り込む前) では 0 行にする。 #}
{% if medical_facility_sources_loaded() %}
{% for year, kind, name in medical_facility_sources() %}
SELECT
    {{ year }} AS survey_year,
    '{{ kind }}' AS table_kind,
    CASE WHEN area_in_cat01 THEN cat01_order ELSE cat02_order END AS area_order,
    CASE WHEN area_in_cat01 THEN cat01_metadata->>'$.name' ELSE cat02_metadata->>'$.name' END
        AS area_label,
    CASE WHEN area_in_cat01 THEN cat02 ELSE cat01 END AS item_code,
    CASE WHEN area_in_cat01 THEN cat02_metadata->>'$.name' ELSE cat01_metadata->>'$.name' END
        AS item_name,
    value
FROM (
    SELECT *, regexp_matches(cat01_metadata->>'$.name', '^[0-9]') AS area_in_cat01
    FROM {{ source('estat_source', name) }}
)
{{ 'UNION ALL' if not loop.last }}
{% endfor %}
{% else %}
SELECT
    NULL::INTEGER AS survey_year, NULL::VARCHAR AS table_kind, NULL::INTEGER AS area_order,
    NULL::VARCHAR AS area_label, NULL::VARCHAR AS item_code, NULL::VARCHAR AS item_name,
    NULL::DOUBLE AS value
WHERE FALSE
{% endif %}
