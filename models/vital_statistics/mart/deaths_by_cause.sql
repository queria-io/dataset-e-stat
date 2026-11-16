{# 選択死因分類は総数 (Se00)・死因 (level 2)・その内訳 (level 3) と再掲が同じ列に並ぶ。
   cause_level に段を出し、再掲 (大腸・路上交通事故) は 'restatement' にする。
   どれにも当たらない段は NULL になり、_schema.yml の not_null で止まる。 #}
SELECT
    s.year,
    a.area_code,
    a.area_name,
    a.area_kind,
    a.prefecture_code,
    s.cause_code,
    REGEXP_REPLACE(cause_name, '^Se[0-9_]+(Se[0-9]+_)?', '') AS cause_name,
    CASE
        WHEN cause_code = 'Se00' THEN 'total'
        WHEN cause_code IN ('Se05Se06', 'Se32_1') THEN 'restatement'
        WHEN cause_meta_level = '2' THEN 'cause'
        WHEN cause_meta_level = '3' THEN 'subcause'
    END AS cause_level,
    s.deaths,
    s.deaths_male,
    s.deaths_female
FROM {{ ref('stg_vital_statistics_deaths_cause') }} AS s
INNER JOIN {{ ref('vital_statistics_area') }} AS a ON a.area = s.area
