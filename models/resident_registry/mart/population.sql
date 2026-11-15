-- 集計行と明細行が同じ表に縦に並ぶ。全国計 (area_level='national')、都道府県、
-- 市区町村のほか、市区町村の行には郡・政令指定都市とその行政区・東京都の
-- 島しょ集計が同居する。どの粒度かは area_code で stg_area を引く。
SELECT
    reference_date,
    year,
    resident_kind,
    area_level,
    area_code,
    lg_code,
    pref_name,
    municipality_name,
    population_total,
    population_male,
    population_female,
    households,
    births,
    deaths,
    natural_change,
    moved_in_total,
    moved_in_domestic,
    moved_in_overseas,
    moved_out_total,
    moved_out_domestic,
    moved_out_overseas,
    social_change,
    other_added,
    other_removed,
    total_added,
    total_removed,
    net_change
FROM {{ ref('stg_resident_population') }}
