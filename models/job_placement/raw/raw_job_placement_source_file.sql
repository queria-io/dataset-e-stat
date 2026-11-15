{{ config(materialized='table') }}
{{ e_stat_source_file_raw('job_placement') }}
