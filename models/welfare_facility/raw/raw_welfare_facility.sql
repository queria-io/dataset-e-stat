-- 社会福祉施設等調査の個別表 施設票 (welfare_facility パイプライン生成の NDJSON)。
-- 施設の符号は先頭ゼロを保つため VARCHAR で読む。値は常勤換算従事者数が
-- 小数を取りうるので DOUBLE。
SELECT
    survey_year,
    area_kind,
    area_label,
    facility_code,
    facility_type,
    facility_parent,
    facility_group,
    facility_level,
    operator,
    survey_form,
    measure,
    value
FROM read_json(
    'data/welfare_facility/facility_statistics.ndjson',
    columns = {
        survey_year: 'INTEGER',
        area_kind: 'VARCHAR',
        area_label: 'VARCHAR',
        facility_code: 'VARCHAR',
        facility_type: 'VARCHAR',
        facility_parent: 'VARCHAR',
        facility_group: 'VARCHAR',
        facility_level: 'VARCHAR',
        operator: 'VARCHAR',
        survey_form: 'VARCHAR',
        measure: 'VARCHAR',
        value: 'DOUBLE'
    },
    format = 'newline_delimited'
)
