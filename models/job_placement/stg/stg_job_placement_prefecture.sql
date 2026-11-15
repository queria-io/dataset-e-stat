{# 期間の種類を英語のコードにし、都道府県コードを足す。年・年度と月の表に分けるのは mart。 #}
SELECT
    CASE period_type
        WHEN '年' THEN 'calendar_year'
        WHEN '年度' THEN 'fiscal_year'
        WHEN '月' THEN 'month'
    END AS period_type,
    year::INTEGER AS year,
    month::INTEGER AS month,
    basis,
    seasonally_adjusted,
    area,
    area_name,
    CASE WHEN area <> '00000' THEN left(area, 2) END AS prefecture_code,
    new_job_openings,
    new_applications,
    active_job_openings,
    active_applicants,
    new_openings_ratio,
    active_openings_ratio,
    source_sha256
FROM {{ ref('raw_job_placement_prefecture') }}
