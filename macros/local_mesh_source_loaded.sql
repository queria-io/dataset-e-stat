{# 手元でだけ取り込むメッシュ統計 (load_local_mesh.py) の source がカタログにあるかを返す。
   CI の main.py はこの source をロードしないので、カタログを空から作り直した直後や、
   初回のロード前には存在しない。そのときに CREATE VIEW が解決できずに dbt build ごと
   止まり、他のテーブルの更新まで止まるのを避けるため、モデルとテストはこれで分岐する。
   parse 時 (execute が偽) は true を返し、依存関係の解決は通常どおり行う。 #}
{% macro local_mesh_source_loaded(table_name) %}
    {% if not execute %}
        {{ return(true) }}
    {% endif %}
    {% set src = source('estat_source', table_name) %}
    {% set rel = adapter.get_relation(database=src.database, schema=src.schema, identifier=src.identifier) %}
    {% if rel is none %}
        {{ log("estat_source." ~ table_name ~ " がカタログに無い。手元で load_local_mesh.py を回すまで 0 行のまま公開する", info=True) }}
    {% endif %}
    {{ return(rel is not none) }}
{% endmacro %}
