SELECT
    s.year,
    a.area_code,
    a.area_name,
    a.area_kind,
    a.prefecture_code,
    s.births,
    s.low_birth_weight_births,
    s.deaths,
    s.infant_deaths,
    s.neonatal_deaths,
    s.early_neonatal_deaths,
    s.spontaneous_fetal_deaths,
    s.induced_fetal_deaths,
    s.late_fetal_deaths,
    s.perinatal_deaths,
    s.marriages,
    s.divorces
FROM {{ ref('stg_vital_statistics_summary') }} AS s
INNER JOIN {{ ref('vital_statistics_area') }} AS a ON a.area = s.area
