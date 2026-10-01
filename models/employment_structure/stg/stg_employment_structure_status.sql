{# 就業構造基本調査の第7-1表を調査年ごとの表から1つに積む。

   2017年（都道府県編）と2022年（地域編）は分類軸の並びとコードが同じ
   （cat01=男女・cat02=配偶関係・cat03=教育・cat04=就業状態等・cat05=年齢）。
   違うのは地域の並びで、2017年は全国・都道府県とその市部（下3桁 001）・政令指定都市、
   2022年は全国・都道府県・政令指定都市・県庁所在都市・人口30万以上の市。
   地域の段はメタ情報の level が年で振り方が違う（2017年は市部が2・政令指定都市が3、
   2022年は市が2）ので、コードから決める。

   教育の「卒業者」は2017年の名称が「うち卒業者」で、同じコード 1 を指す。
   名称は原典のまま残す。

   UNION は列を明示して積む。BY NAME に頼ると、片方の表に e-Stat が軸を足したときに
   列が入れ替わったまま通ってしまう。 #}
{% for y in ['2017', '2022'] %}
SELECT
    TRY_CAST(substr(time, 1, 4) AS INTEGER) AS year,
    area,
    area_metadata->>'$.name' AS area_name,
    CASE
        WHEN area = '00000' THEN 'national'
        WHEN area LIKE '%000' THEN 'prefecture'
        WHEN area LIKE '%001' THEN 'urban_part'
        ELSE 'city'
    END AS area_kind,
    CASE WHEN area <> '00000' AND area <> '00001' THEN substr(area, 1, 2) END AS prefecture_code,
    cat01 AS sex_code,
    cat01_metadata->>'$.name' AS sex,
    cat02 AS marital_status_code,
    cat02_metadata->>'$.name' AS marital_status,
    cat03 AS education_code,
    cat03_metadata->>'$.name' AS education,
    cat04 AS status_code,
    cat04_metadata->>'$.name' AS status,
    TRY_CAST(cat04_metadata->>'$.level' AS INTEGER) AS status_level,
    cat04_metadata->>'$.parent_code' AS status_parent,
    cat05 AS age_class_code,
    cat05_metadata->>'$.name' AS age_class,
    unit,
    TRY_CAST(value AS DOUBLE) AS value
FROM {{ ref('raw_employment_structure_status_' ~ y) }}
{% if not loop.last %}
UNION ALL
{% endif %}
{% endfor %}
