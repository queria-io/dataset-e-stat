{# 学校基本調査 小学校・中学校の市町村別学校数。
   手元でだけ取り込む (load_local.py school_municipality)。source がまだ無いカタログでは 0 行にする。
   都道府県の計の行は municipality_code が NULL。 #}
{% if local_source_loaded('school_municipality_schools') %}
SELECT
    survey_year,
    school_type,
    prefecture_name,
    municipality_code,
    municipality_name,
    founder,
    founder_detail,
    campus,
    value
FROM {{ source('estat_source', 'school_municipality_schools') }}
{% else %}
SELECT
    NULL::INTEGER AS survey_year, NULL::VARCHAR AS school_type, NULL::VARCHAR AS prefecture_name,
    NULL::VARCHAR AS municipality_code, NULL::VARCHAR AS municipality_name,
    NULL::VARCHAR AS founder, NULL::VARCHAR AS founder_detail, NULL::VARCHAR AS campus, NULL::BIGINT AS value
WHERE FALSE
{% endif %}
