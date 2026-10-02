-- 賃金構造基本統計調査 一般労働者 都道府県別 参考表2 (wage_structure パイプライン生成の NDJSON)。
-- 地域コードは先頭ゼロを保つため VARCHAR で読む。
SELECT
    survey_year,
    area,
    area_name,
    prefecture_code,
    industry_code,
    industry,
    sex_code,
    sex,
    scheduled_earnings,
    annual_special_earnings
FROM read_json(
    'data/wage_structure/prefecture_industry.ndjson',
    columns = {
        survey_year: 'INTEGER',
        area: 'VARCHAR',
        area_name: 'VARCHAR',
        prefecture_code: 'VARCHAR',
        industry_code: 'VARCHAR',
        industry: 'VARCHAR',
        sex_code: 'VARCHAR',
        sex: 'VARCHAR',
        scheduled_earnings: 'DOUBLE',
        annual_special_earnings: 'DOUBLE'
    },
    format = 'newline_delimited'
)
