{# 令和3年経済センサス‐活動調査 立地環境特性編
   「商業集積地区（商店街）の小売業・飲食サービス業・生活関連サービス業別、都道府県別、市区町村別の
   商店街数、事業所数、大規模小売店舗数、大規模小売店舗内事業所数、従業者数、売上（収入）金額及び売場面積」
   (統計表 0004015880)。tab=表章項目、cat01=商業集積地区と地域の計、cat02=産業。
   手元でだけ取り込む (load_local.py economic_census_shopping_district)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('economic_census_shopping_district') %}
SELECT
    tab, cat01, cat02, value,
    cat01_metadata, cat02_metadata
FROM {{ source('estat_source', 'economic_census_shopping_district') }}
{% else %}
SELECT
    NULL::VARCHAR AS tab, NULL::VARCHAR AS cat01, NULL::VARCHAR AS cat02, NULL::DOUBLE AS value,
    NULL::JSON AS cat01_metadata, NULL::JSON AS cat02_metadata
WHERE FALSE
{% endif %}
