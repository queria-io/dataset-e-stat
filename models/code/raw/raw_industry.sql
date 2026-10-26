-- 日本標準産業分類の4改定 (industry_code パイプライン生成の NDJSON)。
-- コードは先頭ゼロを保つため VARCHAR で読む。
SELECT
    revision,
    level,
    code,
    name,
    parent_code,
    major_code,
    description,
    examples,
    non_examples
FROM read_json(
    'data/industry_code/industry.ndjson',
    columns = {
        revision: 'INTEGER',
        level: 'VARCHAR',
        code: 'VARCHAR',
        name: 'VARCHAR',
        parent_code: 'VARCHAR',
        major_code: 'VARCHAR',
        description: 'VARCHAR',
        examples: 'VARCHAR',
        non_examples: 'VARCHAR'
    },
    format = 'newline_delimited'
)
