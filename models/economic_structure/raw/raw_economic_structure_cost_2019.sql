{# 2019年経済構造実態調査 二次集計 企業等に関する集計2「事業区分（中分類、一部小分類）別費用内訳割合」
   (統計表 0003414957)。tab=費用項目、cat01=事業区分。
   手元でだけ取り込む (load_local.py economic_structure)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('economic_structure_cost_2019') %}
SELECT
    tab, cat01, area, time, value,
    tab_metadata, cat01_metadata, area_metadata, time_metadata
FROM {{ source('estat_source', 'economic_structure_cost_2019') }}
{% else %}
SELECT
    NULL::VARCHAR AS tab, NULL::VARCHAR AS cat01, NULL::VARCHAR AS area, NULL::VARCHAR AS time, NULL::DOUBLE AS value,
    NULL::JSON AS tab_metadata, NULL::JSON AS cat01_metadata, NULL::JSON AS area_metadata, NULL::JSON AS time_metadata
WHERE FALSE
{% endif %}
