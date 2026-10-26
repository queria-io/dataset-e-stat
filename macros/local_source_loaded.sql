{# 手元でだけ取り込む source (load_local_mesh.py・load_local.py) がカタログにあるかを返す。
   CI の main.py はこれらの source をロードしないので、カタログを空から作り直した直後や、
   初回のロード前には存在しない。そのときに CREATE VIEW が解決できずに dbt build ごと
   止まり、他のテーブルの更新まで止まるのを避けるため、モデルとテストはこれで分岐する。
   parse 時 (execute が偽) は true を返し、依存関係の解決は通常どおり行う。 #}
{% macro local_source_loaded(table_name) %}
    {% if not execute %}
        {{ return(true) }}
    {% endif %}
    {% set src = source('estat_source', table_name) %}
    {% set rel = adapter.get_relation(database=src.database, schema=src.schema, identifier=src.identifier) %}
    {% if rel is none %}
        {{ log("estat_source." ~ table_name ~ " がカタログに無い。手元で取り込むまで 0 行のまま公開する", info=True) }}
    {% endif %}
    {{ return(rel is not none) }}
{% endmacro %}
