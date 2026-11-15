{# 統計表ファイルの取得の記録 (pipelines/source_file.py が data/<主題>/source_file.parquet に書く)。
   raw は取得の記録をそのまま読み、stg で型を付ける。 #}
{% macro e_stat_source_file_raw(topic) %}
SELECT url, page_url, sha256, bytes, media_type, retrieved_at, etag, last_modified
FROM read_parquet('data/{{ topic }}/source_file.parquet')
{% endmacro %}

{% macro e_stat_source_file_stg(raw_model) %}
SELECT
    url,
    page_url,
    sha256,
    bytes::BIGINT AS bytes,
    media_type,
    CAST(retrieved_at AS TIMESTAMPTZ) AS retrieved_at,
    etag,
    last_modified
FROM {{ ref(raw_model) }}
{% endmacro %}
