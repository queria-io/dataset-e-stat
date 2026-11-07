{# 2025年経済産業省企業活動基本調査 確報 第1巻 研究開発に関する表 第10表 産業別、企業数、売上高、研究開発費及び売上高比率、受託研究費、研究開発投資、能力開発費
   (統計表 0004062626)。cat01=表頭（測定項目）、cat02=表側（産業 × 内訳 × 年度をつないだ名称）。
   手元でだけ取り込む (load_local.py enterprise_activity)。source がまだ無いカタログでは 0 行にする。 #}
{% if local_source_loaded('enterprise_activity_research_2025') %}
SELECT
    cat01, cat02, value,
    cat01_metadata, cat02_metadata
FROM {{ source('estat_source', 'enterprise_activity_research_2025') }}
{% else %}
SELECT
    NULL::VARCHAR AS cat01, NULL::VARCHAR AS cat02, NULL::DOUBLE AS value,
    NULL::JSON AS cat01_metadata, NULL::JSON AS cat02_metadata
WHERE FALSE
{% endif %}
