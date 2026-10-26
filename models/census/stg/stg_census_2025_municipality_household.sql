{# 令和7年国勢調査 人口等基本集計「世帯の種類別世帯数及び世帯人員」(統計表 0004065901)。
   2020年の stg_census_municipality_household と同じ形。tab のコードだけ 2025_ で始まる。
   単位が tab で変わる(世帯 / 人)ので、縦持ちのまま合計してはいけない。 #}
SELECT
    area,
    tab,
    tab_metadata->>'$.name' AS item_name,
    cat01,
    cat01_metadata->>'$.name' AS household_type,
    unit,
    TRY_CAST(value AS BIGINT) AS value
FROM {{ ref('raw_census_2025_municipality_household') }}
