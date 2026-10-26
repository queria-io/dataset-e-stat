{# 医療施設調査「病院数；病床数，病院－病床の種類・二次医療圏・市区町村別」と
   「一般診療所数；歯科診療所数；病床数，病床の有無・二次医療圏・市区町村別」を年ごとに
   1 表ずつ取り込んだ元表 (load_local.py の medical_facility) を縦に積む。

   地域と項目のどちらが cat01 に入るかは年で違う (2014 年だけ地域が cat01)。地域の
   名称は「01202 函館市」のようにコードを前置するので、名称が数字で始まる軸を地域とみる。
   年と表の種類は統計表そのものが表すので、元表の名前から付ける。
   地域の並び (area_order) は取得時に残したメタ情報の順。二次医療圏の所属を読むのに使う。
   2013 年の表は取り込んでいない (local_tables.yml)。 #}
{% set first_year = 2008 %}
{% set last_year = 2024 %}
{% set years = range(first_year, last_year + 1) | reject('equalto', 2013) | list %}
{% for year in years %}
{% for kind in ['hospital', 'clinic'] %}
SELECT
    {{ year }} AS survey_year,
    '{{ kind }}' AS table_kind,
    CASE WHEN regexp_matches(cat01_metadata->>'$.name', '^[0-9]') THEN cat01_order ELSE cat02_order END
        AS area_order,
    CASE WHEN regexp_matches(cat01_metadata->>'$.name', '^[0-9]')
        THEN cat01_metadata->>'$.name' ELSE cat02_metadata->>'$.name' END AS area_label,
    CASE WHEN regexp_matches(cat01_metadata->>'$.name', '^[0-9]') THEN cat02 ELSE cat01 END
        AS item_code,
    CASE WHEN regexp_matches(cat01_metadata->>'$.name', '^[0-9]')
        THEN cat02_metadata->>'$.name' ELSE cat01_metadata->>'$.name' END AS item_name,
    value
FROM {{ source('estat_source', 'medical_facility_' ~ year ~ '_' ~ kind) }}
{{ 'UNION ALL' if not loop.last }}
{% endfor %}
{{ 'UNION ALL' if not loop.last }}
{% endfor %}
