{# 母の年齢の総数 (00100) は落とし、5歳階級 9 区分と不詳だけ残す。
   残した 10 区分を足すと vital_events の births に一致する。 #}
SELECT
    year,
    area_code,
    area_name,
    area_kind,
    prefecture_code,
    mother_age_code,
    mother_age_class,
    CASE mother_age_code
        WHEN '00190' THEN NULL
        WHEN '00450' THEN NULL
        ELSE CAST(NULLIF(REGEXP_EXTRACT(mother_age_class, '^(\d+)', 1), '') AS INTEGER)
    END AS mother_age_from,
    CASE
        WHEN mother_age_code = '00190' THEN 14
        WHEN mother_age_code IN ('00310', '00450') THEN NULL
        ELSE CAST(NULLIF(REGEXP_EXTRACT(mother_age_class, '～(\d+)歳', 1), '') AS INTEGER)
    END AS mother_age_to,
    births,
    births_male,
    births_female
FROM {{ ref('stg_vital_statistics_births_mother_age') }}
WHERE mother_age_code <> '00100'
