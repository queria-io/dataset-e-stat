SELECT
    i.fiscal_year,
    s.prefecture_code,
    i.prefecture_name,
    i.insurer_name,
    s.insurer_kind,
    s.area_code,
    i.category,
    i.value
FROM {{ ref('raw_kaigo_insurance_insured') }} i
JOIN {{ ref('stg_kaigo_insurance_insurer') }} s
    ON s.fiscal_year = i.fiscal_year
    AND s.prefecture_name = i.prefecture_name
    AND s.insurer_name IS NOT DISTINCT FROM i.insurer_name
