{# 住民基本台帳人口移動報告の参考表 (load_local.py の migration_od) の元表。
   年ごとに転出先別 (outflow: 移動後の住所地別転出者数) と転入元別 (inflow: 移動前の
   住所地別転入者数) が 1 表ずつある。

   前住地と現住地のどちらが cat01 に入るかは表で違う。e-Stat のメタ情報の軸名で確かめた
   (2026-11-09 時点):
     outflow 2012〜2017 年: cat01=現住地 / area=前住地、2018 年〜: cat01=前住地 / area=現住地
     inflow  2012〜2018 年: cat01=前住地 / area=現住地、2019 年〜: cat01=現住地 / area=前住地
   値の側から見分ける手がかりは無い (どちらの軸も同じ地域コードの体系) ので、表ごとに書く。
   新しい年の表を足すときは getMetaInfo の CLASS_OBJ の @name で確かめる。 #}
{% macro migration_od_sources() %}
    {% set out = [] %}
    {% for year in range(2012, 2026) %}
        {% do out.append((year, 'outflow', 'migration_od_outflow_' ~ year, year >= 2018)) %}
        {% do out.append((year, 'inflow', 'migration_od_inflow_' ~ year, year <= 2018)) %}
    {% endfor %}
    {{ return(out) }}
{% endmacro %}

{# 元表が全部カタログにあるか。1 つでも欠けるとモデルは 0 行、テストは検査しない。 #}
{% macro migration_od_sources_loaded() %}
    {% for _, _, name, _ in migration_od_sources() %}
        {% if not local_source_loaded(name) %}
            {{ return(false) }}
        {% endif %}
    {% endfor %}
    {{ return(true) }}
{% endmacro %}
