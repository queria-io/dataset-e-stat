{# 法人企業統計調査 時系列データ 金融業、保険業以外の業種（原数値・年度）の2007年度以前。
   手元でだけ取り込む (load_local.py corporate_finance_history)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('corporate_finance_nonfinancial_annual_pre2008') %}
SELECT
    cat01, cat02, cat03, time, unit, value,
    cat01_metadata, cat02_metadata, cat03_metadata, time_metadata
FROM {{ source('estat_source', 'corporate_finance_nonfinancial_annual_pre2008') }}
{% else %}
SELECT
    NULL::VARCHAR AS cat01, NULL::VARCHAR AS cat02, NULL::VARCHAR AS cat03, NULL::VARCHAR AS time,
    NULL::VARCHAR AS unit, NULL::DOUBLE AS value,
    NULL::JSON AS cat01_metadata, NULL::JSON AS cat02_metadata, NULL::JSON AS cat03_metadata, NULL::JSON AS time_metadata
WHERE FALSE
{% endif %}
