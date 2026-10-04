-- 学校基本調査 小学校の学年別児童数・中学校の学年別生徒数 (school パイプライン生成の NDJSON)。
-- 地域コードは先頭ゼロを保つため VARCHAR で読む。
SELECT
    survey_year,
    school_type,
    founder_code,
    area,
    area_label,
    prefecture_code,
    grade,
    sex_code,
    students
FROM read_json(
    'data/school/enrollment_by_grade.ndjson',
    columns = {
        survey_year: 'INTEGER',
        school_type: 'VARCHAR',
        founder_code: 'VARCHAR',
        area: 'VARCHAR',
        area_label: 'VARCHAR',
        prefecture_code: 'VARCHAR',
        grade: 'INTEGER',
        sex_code: 'VARCHAR',
        students: 'BIGINT'
    },
    format = 'newline_delimited'
)
