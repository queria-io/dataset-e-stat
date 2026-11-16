{# 母の年齢の総数 (00100) は落とし、5歳階級 9 区分と不詳だけ残す。
   残した 10 区分を足すと vital_events の births に一致する。 #}
SELECT
    s.year,
    a.area_code,
    a.area_name,
    a.area_kind,
    a.prefecture_code,
    s.mother_age_code,
    s.mother_age_class,
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
    s.births,
    s.births_male,
    s.births_female
FROM {{ ref('stg_vital_statistics_births_mother_age') }} AS s
INNER JOIN {{ ref('vital_statistics_area') }} AS a ON a.area = s.area
WHERE mother_age_code <> '00100'
