SELECT
    year,
    month,
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
    active_openings_ratio
FROM {{ ref('raw_job_placement_prefecture') }}
WHERE period_type = '月'
ORDER BY basis, seasonally_adjusted, area, year, month
