-- 作物統計調査 野菜生産出荷統計 都道府県別の作付面積・10a当たり収量・収穫量・出荷量 (crop パイプライン生成の NDJSON)。
-- 地域コードは先頭ゼロを保つため VARCHAR で読む。
SELECT
    year,
    crop,
    season,
    subset,
    area,
    area_name,
    prefecture_code,
    planted_area_ha,
    yield_kg_per_10a,
    harvest_t,
    shipment_t
FROM read_json(
    'data/crop/vegetable_prefecture.ndjson',
    columns = {
        year: 'INTEGER',
        crop: 'VARCHAR',
        season: 'VARCHAR',
        subset: 'VARCHAR',
        area: 'VARCHAR',
        area_name: 'VARCHAR',
        prefecture_code: 'VARCHAR',
        planted_area_ha: 'DOUBLE',
        yield_kg_per_10a: 'DOUBLE',
        harvest_t: 'DOUBLE',
        shipment_t: 'DOUBLE'
    },
    format = 'newline_delimited'
)
