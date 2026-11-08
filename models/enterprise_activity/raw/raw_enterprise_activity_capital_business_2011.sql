{# 経済産業省企業活動基本調査 確報（統計表 0003340743）。2020年より前の調査の書き方の表。
   cat01=表頭（測定項目）、cat02=表側。cat01_order はメタ情報の並び順（0 始まり）。
   手元でだけ取り込む (load_local.py enterprise_activity_legacy)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('enterprise_activity_capital_business_2011') %}
SELECT
    cat01, cat02, value, cat01_order,
    cat01_metadata, cat02_metadata
FROM {{ source('estat_source', 'enterprise_activity_capital_business_2011') }}
{% else %}
SELECT
    NULL::VARCHAR AS cat01, NULL::VARCHAR AS cat02, NULL::DOUBLE AS value, NULL::INTEGER AS cat01_order,
    NULL::JSON AS cat01_metadata, NULL::JSON AS cat02_metadata
WHERE FALSE
{% endif %}
