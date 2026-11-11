{# 一般職業紹介状況（職業安定業務統計）の都道府県（受理地・就業地）別の労働市場関係指標。main.py の
   build_job_placement が毎回 e-Stat の統計表ファイルから取り直して data/job_placement/ に書く。 #}
{{ config(materialized='table') }}
SELECT period_type, year::INTEGER AS year, month::INTEGER AS month, basis, seasonally_adjusted, area, area_name,
    new_job_openings, new_applications, active_job_openings, active_applicants,
    new_openings_ratio, active_openings_ratio
FROM read_parquet('data/job_placement/prefecture_*.parquet')
