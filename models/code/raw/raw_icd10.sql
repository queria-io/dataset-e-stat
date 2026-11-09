-- classification_code パイプラインが作る NDJSON。
-- コードは先頭ゼロを保つため VARCHAR で読む。
SELECT
    revision,
    level,
    code,
    name,
    parent_code,
    chapter_code
FROM read_json(
    'data/classification_code/icd10.ndjson',
    columns = {
        revision: 'INTEGER',
        level: 'VARCHAR',
        code: 'VARCHAR',
        name: 'VARCHAR',
        parent_code: 'VARCHAR',
        chapter_code: 'VARCHAR'
    },
    format = 'newline_delimited'
)
