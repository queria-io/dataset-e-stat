{# 医療施設調査の元表 (load_local.py の medical_facility) を (年, 表の種類, 元表名) で返す。
   2013 年の表は取り込んでいない (local_tables.yml)。 #}
{% macro medical_facility_sources() %}
    {% set out = [] %}
    {% for year in range(2008, 2025) if year != 2013 %}
        {% for kind in ['hospital', 'clinic'] %}
            {% do out.append((year, kind, 'medical_facility_' ~ year ~ '_' ~ kind)) %}
        {% endfor %}
    {% endfor %}
    {{ return(out) }}
{% endmacro %}

{# 元表が全部カタログにあるか。1 つでも欠けると (初回のロード前・空から作り直した直後)
   モデルは 0 行、テストは検査しない。一部の年だけで組むと、年が欠けたまま公開される。 #}
{% macro medical_facility_sources_loaded() %}
    {% for _, _, name in medical_facility_sources() %}
        {% if not local_source_loaded(name) %}
            {{ return(false) }}
        {% endif %}
    {% endfor %}
    {{ return(true) }}
{% endmacro %}
