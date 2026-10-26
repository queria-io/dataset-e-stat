{# 令和3年経済センサス‐活動調査 卸売業，小売業に関する集計 産業編（市区町村表）
   第2表「産業分類（卸売業計・小売業中分類）別事業所数、従業者数、年間商品販売額及び売場面積（小売業）－全国、都道府県、市部、町村」
   (統計表 0004003264)。tab=表章項目、cat01=産業分類。
   手元でだけ取り込む (load_local.py economic_census_retail)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('economic_census_retail_town') %}
SELECT
    tab, cat01, area, value,
    cat01_metadata, area_metadata
FROM {{ source('estat_source', 'economic_census_retail_town') }}
{% else %}
SELECT
    NULL::VARCHAR AS tab, NULL::VARCHAR AS cat01, NULL::VARCHAR AS area, NULL::DOUBLE AS value,
    NULL::JSON AS cat01_metadata, NULL::JSON AS area_metadata
WHERE FALSE
{% endif %}
