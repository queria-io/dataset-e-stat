{# 経済構造実態調査の産業コードを日本標準産業分類のコードにそろえる。

   2024年までの表は産業分類の軸に表内の通し番号（00, 01, 0101 …）を振り、
   分類コードは名称の先頭に置いている（「09 食料品製造業」「A～R 全産業」）。
   2025年からは分類コードそのもの（AR, A, 09, 091）を軸のコードにしている。
   古い年は名称の先頭の語をコードとして取り、「A～R」のような範囲は AR に縮める。 #}
{% macro e_stat_economic_structure_industry_code(year, code, name) %}
CASE
    WHEN {{ year }} >= 2025 THEN {{ code }}
    ELSE replace(regexp_extract({{ name }}, '^(\S+)', 1), '～', '')
END
{% endmacro %}

{% macro e_stat_economic_structure_industry_name(year, name) %}
CASE
    WHEN {{ year }} >= 2025 THEN {{ name }}
    ELSE regexp_replace({{ name }}, '^\S+\s+', '')
END
{% endmacro %}

{# 産業コードの形から分類の段を決める。メタ情報の level は年で振り方が違う
   （2019・2020年は大分類が 2、2022年からは 3）ので使わない。 #}
{% macro e_stat_economic_structure_industry_level(code) %}
CASE
    WHEN {{ code }} IN ('AR', 'ER') THEN 'total'
    WHEN {{ code }} IN ('AB', 'CR') THEN 'sector'
    WHEN regexp_full_match({{ code }}, '[A-T]') THEN 'division'
    WHEN regexp_full_match({{ code }}, '[A-T][0-9]') THEN 'division_part'
    WHEN regexp_full_match({{ code }}, '[0-9]{2}') THEN 'major_group'
    WHEN regexp_full_match({{ code }}, '[0-9]{3}') THEN 'group'
    ELSE 'group_part'
END
{% endmacro %}
