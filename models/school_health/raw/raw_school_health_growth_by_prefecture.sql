-- 学校保健統計調査 都道府県別の身長・体重・座高の平均値と標準偏差 (school_health パイプライン生成の NDJSON)。
-- 地域コードは先頭ゼロを保つため VARCHAR で読む。
SELECT
    survey_year,
    age,
    sex_code,
    area,
    area_label,
    prefecture_code,
    height_mean,
    height_sd,
    weight_mean,
    weight_sd,
    sitting_height_mean,
    sitting_height_sd
FROM read_json(
    'data/school_health/growth_by_prefecture.ndjson',
    columns = {
        survey_year: 'INTEGER',
        age: 'INTEGER',
        sex_code: 'VARCHAR',
        area: 'VARCHAR',
        area_label: 'VARCHAR',
        prefecture_code: 'VARCHAR',
        height_mean: 'DOUBLE',
        height_sd: 'DOUBLE',
        weight_mean: 'DOUBLE',
        weight_sd: 'DOUBLE',
        sitting_height_mean: 'DOUBLE',
        sitting_height_sd: 'DOUBLE'
    },
    format = 'newline_delimited'
)
