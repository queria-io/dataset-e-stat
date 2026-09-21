-- 介護サービス施設・事業所調査の閲覧表 第1表 (kaigo_service パイプライン生成の NDJSON)。
-- 標準地域コードは先頭ゼロを保つため VARCHAR で読む。値は常勤換算従事者数が
-- 小数を取りうるので DOUBLE。
SELECT
    survey_year,
    area_code,
    area_name,
    area_kind,
    prefecture_code,
    facility_type,
    survey_form,
    measure,
    value
FROM read_json(
    'data/kaigo_service/insurance_facility.ndjson',
    columns = {
        survey_year: 'INTEGER',
        area_code: 'VARCHAR',
        area_name: 'VARCHAR',
        area_kind: 'VARCHAR',
        prefecture_code: 'VARCHAR',
        facility_type: 'VARCHAR',
        survey_form: 'VARCHAR',
        measure: 'VARCHAR',
        value: 'DOUBLE'
    },
    format = 'newline_delimited'
)
