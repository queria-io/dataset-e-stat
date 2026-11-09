-- classification_code パイプラインが作る NDJSON。
-- コードは先頭ゼロを保つため VARCHAR で読む。
SELECT
    revision,
    level,
    code,
    name,
    parent_code
FROM read_json(
    'data/classification_code/commodity.ndjson',
    columns = {
        revision: 'INTEGER',
        level: 'INTEGER',
        code: 'VARCHAR',
        name: 'VARCHAR',
        parent_code: 'VARCHAR'
    },
    format = 'newline_delimited'
)
