{# item_name / unit / 上位項目は item_code で一意化した item_lookup (公開名 stg_item_lookup) から引く。
   item_catalog を直接 JOIN すると、同じ item_code が掲載統計表の数だけ存在するため
   観測値1行が最大3行に複製される。

   cat01_parent は、上位項目と内訳が同じ列に混在していることを絞り込みで扱えるように
   出している。`WHERE cat01_parent IS NULL` で項目だけ、`WHERE cat01_parent = 'J1104'`
   でその副区分だけを取れる。 #}
{% macro e_stat_mart_view(source_ref) %}
SELECT
    s.cat01,
    COALESCE(c.item_name, s.item_name) AS item_name,
    c.parent_code AS cat01_parent,
    s.area,
    s.area_name,
    s.time_name,
    s.year,
    COALESCE(c.unit, s.unit) AS unit,
    s.value
FROM {{ ref(source_ref) }} s
LEFT JOIN {{ ref('item_lookup') }} c ON s.cat01 = c.item_code
{% endmacro %}
