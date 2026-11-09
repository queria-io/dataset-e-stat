-- classification_code パイプラインが作る NDJSON。
-- コードは先頭ゼロを保つため VARCHAR で読む。
SELECT
    revision,
    level,
    code,
    name,
    parent_code,
    major_code,
    description
FROM read_json(
    'data/classification_code/industry_economic_census.ndjson',
    columns = {
        revision: 'INTEGER',
        level: 'VARCHAR',
        code: 'VARCHAR',
        name: 'VARCHAR',
        parent_code: 'VARCHAR',
        major_code: 'VARCHAR',
        description: 'VARCHAR'
    },
    format = 'newline_delimited'
)
