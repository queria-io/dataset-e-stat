{# 年齢の総数 (00100) と 0〜4歳の各歳 (メタ情報の level 3) は落とし、5歳階級 21 区分と
   不詳だけ残す。残した 22 区分を足すと地域の死亡数の総数に一致する。
   0歳の死亡は vital_events の infant_deaths にある。 #}
SELECT
    year,
    area_code,
    area_name,
    area_kind,
    prefecture_code,
    age_code,
    age_class,
    CAST(NULLIF(REGEXP_EXTRACT(age_class, '^(\d+)', 1), '') AS INTEGER) AS age_from,
    CAST(NULLIF(REGEXP_EXTRACT(age_class, '～(\d+)歳', 1), '') AS INTEGER) AS age_to,
    deaths,
    deaths_male,
    deaths_female
FROM {{ ref('stg_vital_statistics_deaths_age') }}
WHERE age_code <> '00100'
    AND age_meta_level = '2'
