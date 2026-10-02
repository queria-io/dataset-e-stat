-- 賃金構造基本統計調査 一般労働者 都道府県別 参考表1 (wage_structure パイプライン生成の NDJSON)。
-- 地域コードは先頭ゼロを保つため VARCHAR で読む。
SELECT
    survey_year,
    area,
    area_name,
    prefecture_code,
    sex_code,
    sex,
    age,
    tenure_years,
    scheduled_hours,
    overtime_hours,
    contractual_earnings,
    scheduled_earnings,
    annual_special_earnings,
    workers
FROM read_json(
    'data/wage_structure/prefecture.ndjson',
    columns = {
        survey_year: 'INTEGER',
        area: 'VARCHAR',
        area_name: 'VARCHAR',
        prefecture_code: 'VARCHAR',
        sex_code: 'VARCHAR',
        sex: 'VARCHAR',
        age: 'DOUBLE',
        tenure_years: 'DOUBLE',
        scheduled_hours: 'DOUBLE',
        overtime_hours: 'DOUBLE',
        contractual_earnings: 'DOUBLE',
        scheduled_earnings: 'DOUBLE',
        annual_special_earnings: 'DOUBLE',
        workers: 'DOUBLE'
    },
    format = 'newline_delimited'
)
