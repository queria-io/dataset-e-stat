{# 介護保険事業状況報告 (年報) 第4表 保険者別 要介護 (要支援) 認定者数 (男女計)。
   手元でだけ取り込む (load_local.py kaigo_insurance)。source がまだ無いカタログでは 0 行にする。
   全国の行は insurer_name が NULL。 #}
{% if local_source_loaded('kaigo_insurance_certified') %}
SELECT
    fiscal_year,
    prefecture_name,
    insurer_name,
    insured_category,
    age_group,
    care_level,
    value
FROM {{ source('estat_source', 'kaigo_insurance_certified') }}
{% else %}
SELECT
    NULL::INTEGER AS fiscal_year, NULL::VARCHAR AS prefecture_name, NULL::VARCHAR AS insurer_name,
    NULL::VARCHAR AS insured_category, NULL::VARCHAR AS age_group, NULL::VARCHAR AS care_level,
    NULL::BIGINT AS value
WHERE FALSE
{% endif %}
