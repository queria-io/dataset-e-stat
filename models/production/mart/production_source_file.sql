{{ config(alias='source_file') }}

SELECT url, page_url, sha256, bytes, media_type, retrieved_at, etag, last_modified
FROM {{ ref('stg_production_source_file') }}
ORDER BY retrieved_at, url
