-- 介護サービス施設・事業所調査 基本票の事業所数の 4 表 (kaigo_service パイプライン生成の NDJSON)。
-- 行見出しは地域名だけで、標準地域コードは stg で当てる。値は原典が整数で出すが、
-- insurance_facility にそろえて DOUBLE で受ける。
SELECT
    survey_year,
    area_name,
    area_kind,
    service_category,
    service_type,
    value
FROM read_json(
    'data/kaigo_service/service_establishment.ndjson',
    columns = {
        survey_year: 'INTEGER',
        area_name: 'VARCHAR',
        area_kind: 'VARCHAR',
        service_category: 'VARCHAR',
        service_type: 'VARCHAR',
        value: 'DOUBLE'
    },
    format = 'newline_delimited'
)
