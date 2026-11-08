{# 2024年経済構造実態調査 三次集計 事業所に関する集計1「産業（大分類）別事業所数及び売上（収入）金額」
   (統計表 0004032882)。tab=表章項目、cat01=産業分類、area=全国・都道府県。
   手元でだけ取り込む (load_local.py economic_structure)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('economic_structure_establishment_2024') %}
SELECT
    tab, cat01, area, time, value,
    tab_metadata, cat01_metadata, area_metadata, time_metadata
FROM {{ source('estat_source', 'economic_structure_establishment_2024') }}
{% else %}
SELECT
    NULL::VARCHAR AS tab, NULL::VARCHAR AS cat01, NULL::VARCHAR AS area, NULL::VARCHAR AS time, NULL::DOUBLE AS value,
    NULL::JSON AS tab_metadata, NULL::JSON AS cat01_metadata, NULL::JSON AS area_metadata, NULL::JSON AS time_metadata
WHERE FALSE
{% endif %}
