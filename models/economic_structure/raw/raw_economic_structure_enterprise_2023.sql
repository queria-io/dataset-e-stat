{# 2023年経済構造実態調査 二次集計 企業等に関する集計1「企業産業（小分類）、経営組織別企業等数、売上（収入）金額、年間商品販売額、費用総額、主な費用項目及び付加価値額」
   (統計表 0004018720)。tab=表章項目、cat01=企業産業分類、cat02=経営組織。
   手元でだけ取り込む (load_local.py economic_structure)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('economic_structure_enterprise_2023') %}
SELECT
    tab, cat01, cat02, area, time, value,
    tab_metadata, cat01_metadata, cat02_metadata, area_metadata, time_metadata
FROM {{ source('estat_source', 'economic_structure_enterprise_2023') }}
{% else %}
SELECT
    NULL::VARCHAR AS tab, NULL::VARCHAR AS cat01, NULL::VARCHAR AS cat02, NULL::VARCHAR AS area, NULL::VARCHAR AS time, NULL::DOUBLE AS value,
    NULL::JSON AS tab_metadata, NULL::JSON AS cat01_metadata, NULL::JSON AS cat02_metadata, NULL::JSON AS area_metadata, NULL::JSON AS time_metadata
WHERE FALSE
{% endif %}
