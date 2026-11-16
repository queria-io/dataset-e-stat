{# code.municipality と code.municipality_change を soumu へ移した後始末。
   モデルファイルを消しても DuckLake 側のテーブル・ビューは残るので、公開中のバージョンから落とす。
   ビュー（stg）を先に、テーブルを後に落とす。DROP はデータベース名まで修飾する (既定のデータベースは :memory:)。
   本番の Apply が 1 回通ったら、この macro と dbt_project.yml の on-run-start をまとめて消してよい #}
{% macro drop_retired_municipality_code() %}
  {% if not execute %}{{ return('') }}{% endif %}
  {% set names = "'municipality', 'municipality_change', 'raw_municipality', 'raw_municipality_change',"
      ~ " 'stg_municipality', 'stg_municipality_change'" %}
  {% for kind, catalog, column in [('VIEW', 'duckdb_views()', 'view_name'), ('TABLE', 'duckdb_tables()', 'table_name')] %}
    {% set found = run_query(
        "SELECT " ~ column ~ " FROM " ~ catalog
        ~ " WHERE database_name = 'e_stat' AND schema_name = 'code' AND " ~ column ~ " IN (" ~ names ~ ")"
    ) %}
    {% for row in found.rows %}
      {% do log('dropping retired ' ~ kind ~ ' e_stat.code.' ~ row[0], info=True) %}
      {% do run_query('DROP ' ~ kind ~ ' e_stat.code."' ~ row[0] ~ '"') %}
    {% endfor %}
  {% endfor %}
{% endmacro %}
