SELECT
    c.fiscal_year,
    s.prefecture_code,
    c.prefecture_name,
    c.insurer_name,
    s.insurer_kind,
    s.area_code,
    c.insured_category,
    c.age_group,
    c.care_level,
    c.value
FROM {{ ref('raw_kaigo_insurance_certified') }} c
JOIN {{ ref('stg_kaigo_insurance_insurer') }} s
    ON s.fiscal_year = c.fiscal_year
    AND s.prefecture_name = c.prefecture_name
    AND s.insurer_name IS NOT DISTINCT FROM c.insurer_name
