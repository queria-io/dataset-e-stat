SELECT
    year,
    month,
    basis,
    seasonally_adjusted,
    area,
    area_name,
    prefecture_code,
    new_job_openings,
    new_applications,
    active_job_openings,
    active_applicants,
    new_openings_ratio,
    active_openings_ratio,
    source_sha256
FROM {{ ref('stg_job_placement_prefecture') }}
WHERE period_type = 'month'
ORDER BY basis, seasonally_adjusted, area, year, month
