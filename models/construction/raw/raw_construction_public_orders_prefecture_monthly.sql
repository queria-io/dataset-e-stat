-- 建設工事受注動態統計調査 公共工事の発注機関別・施工都道府県別請負契約額 (construction_orders パイプライン生成の NDJSON)。
-- 地域コードは先頭ゼロを保つため VARCHAR で読む。
SELECT
    year,
    month,
    area,
    prefecture_code,
    area_name,
    total,
    national_total,
    national_government,
    independent_agency,
    government_affiliated,
    local_total,
    prefectural_government,
    municipal_government,
    local_public_enterprise,
    other
FROM read_json(
    'data/construction_orders/public_orders_prefecture_monthly.ndjson',
    columns = {
        year: 'INTEGER',
        month: 'INTEGER',
        area: 'VARCHAR',
        prefecture_code: 'VARCHAR',
        area_name: 'VARCHAR',
        total: 'DOUBLE',
        national_total: 'DOUBLE',
        national_government: 'DOUBLE',
        independent_agency: 'DOUBLE',
        government_affiliated: 'DOUBLE',
        local_total: 'DOUBLE',
        prefectural_government: 'DOUBLE',
        municipal_government: 'DOUBLE',
        local_public_enterprise: 'DOUBLE',
        other: 'DOUBLE'
    },
    format = 'newline_delimited'
)
