-- 廃置分合等の一覧 (raw_municipality_history_event)。施行日を DATE にする。
SELECT
    pattern,
    area_code,
    pref_name,
    parent_name,
    name,
    CAST(effective_date AS DATE) AS effective_date,
    reason
FROM {{ ref('raw_municipality_history_event') }}
