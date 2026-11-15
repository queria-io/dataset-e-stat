{# 普通貿易統計 品別国別表の過去の年 (raw_trade_history) と新しい年 (raw_trade_recent) に、
   同じ列を付ける。輸出入の名前と HS コードの上位の桁を足し、金額の列名に単位を付ける。 #}
{% macro e_stat_trade_stg(raw_model) %}
SELECT
    flow,
    CASE flow WHEN 'export' THEN '輸出' WHEN 'import' THEN '輸入' END AS flow_name,
    year,
    month,
    hs_code,
    substr(hs_code, 1, 2) AS hs2,
    substr(hs_code, 1, 4) AS hs4,
    substr(hs_code, 1, 6) AS hs6,
    country_code,
    unit1,
    unit2,
    quantity1,
    quantity2,
    value AS value_thousand_yen,
    release,
    source_sha256
FROM {{ ref(raw_model) }}
{% endmacro %}
