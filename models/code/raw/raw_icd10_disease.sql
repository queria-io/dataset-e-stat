-- classification_code パイプラインが作る NDJSON。
-- コードは先頭ゼロを保つため VARCHAR で読む。
SELECT
    revision,
    table_kind,
    code,
    name,
    parent_code,
    icd10_codes
FROM read_json(
    'data/classification_code/icd10_disease.ndjson',
    columns = {
        revision: 'INTEGER',
        table_kind: 'VARCHAR',
        code: 'VARCHAR',
        name: 'VARCHAR',
        parent_code: 'VARCHAR',
        icd10_codes: 'VARCHAR'
    },
    format = 'newline_delimited'
)
