SELECT
    CASE period_type WHEN '年' THEN 'calendar_year' WHEN '年度' THEN 'fiscal_year' END AS period_type,
    year,
    basis,
    area,
    area_name,
    CASE WHEN area <> '00000' THEN left(area, 2) END AS prefecture_code,
    new_job_openings,
    new_applications,
    active_job_openings,
    active_applicants,
    new_openings_ratio,
    active_openings_ratio
FROM {{ ref('raw_job_placement_prefecture') }}
WHERE period_type IN ('年', '年度')
ORDER BY period_type, basis, area, year
