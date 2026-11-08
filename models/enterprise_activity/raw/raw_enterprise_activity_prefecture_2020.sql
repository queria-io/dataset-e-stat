{# 2020年経済産業省企業活動基本調査 確報 第1巻 地域に関する表 第16表 産業別、都道府県別、企業数、事業所数、従業者数、…
   (統計表 0003458234)。cat01=表頭（測定項目）、cat02=表側（産業 × 内訳 × 年度をつないだ名称）。
   手元でだけ取り込む (load_local.py enterprise_activity)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('enterprise_activity_prefecture_2020') %}
SELECT
    cat01, cat02, value,
    cat01_metadata, cat02_metadata
FROM {{ source('estat_source', 'enterprise_activity_prefecture_2020') }}
{% else %}
SELECT
    NULL::VARCHAR AS cat01, NULL::VARCHAR AS cat02, NULL::DOUBLE AS value,
    NULL::JSON AS cat01_metadata, NULL::JSON AS cat02_metadata
WHERE FALSE
{% endif %}
