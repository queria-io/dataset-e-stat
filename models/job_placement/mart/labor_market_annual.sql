SELECT
    period_type,
    year,
    basis,
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
WHERE period_type IN ('calendar_year', 'fiscal_year')
ORDER BY period_type, basis, area, year
