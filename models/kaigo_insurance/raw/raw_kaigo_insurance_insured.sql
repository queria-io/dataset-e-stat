{# 介護保険事業状況報告 (年報) 第2表 保険者別 第1号被保険者数。
   手元でだけ取り込む (load_local.py kaigo_insurance)。source がまだ無いカタログでは 0 行にする。
   全国の行は insurer_name が NULL。 #}
{% if local_source_loaded('kaigo_insurance_insured') %}
SELECT
    fiscal_year,
    prefecture_name,
    insurer_name,
    category,
    value
FROM {{ source('estat_source', 'kaigo_insurance_insured') }}
{% else %}
SELECT
    NULL::INTEGER AS fiscal_year, NULL::VARCHAR AS prefecture_name, NULL::VARCHAR AS insurer_name,
    NULL::VARCHAR AS category, NULL::BIGINT AS value
WHERE FALSE
{% endif %}
