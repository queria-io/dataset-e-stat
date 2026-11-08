{# 法人企業景気予測調査の BSI（景況判断・従業員数判断・設備判断）を1つに積む。
   景況判断の表だけ、cat04 に貴社・国内の区別がある。従業員数判断・設備判断は貴社だけ。
   調査期（time）は「2026年7～9月期」の形で、コードは YYYY00MMMM。 #}
WITH unioned AS (
    SELECT
        CASE cat04 WHEN '10' THEN '景況判断（貴社）' WHEN '20' THEN '景況判断（国内）' END AS indicator,
        cat01, cat01_metadata, cat02, cat02_metadata, cat03, cat03_metadata, time, time_metadata, value
    FROM {{ ref('raw_business_outlook_conditions_bsi') }}
    UNION ALL
    SELECT '従業員数判断' AS indicator,
        cat01, cat01_metadata, cat02, cat02_metadata, cat03, cat03_metadata, time, time_metadata, value
    FROM {{ ref('raw_business_outlook_employment_bsi') }}
    UNION ALL
    SELECT '設備判断' AS indicator,
        cat01, cat01_metadata, cat02, cat02_metadata, cat03, cat03_metadata, time, time_metadata, value
    FROM {{ ref('raw_business_outlook_equipment_bsi') }}
)

SELECT
    time AS survey_time,
    replace(time_metadata->>'$.name', '～', '〜') AS survey_name,
    CAST(substr(time, 1, 4) AS INTEGER) AS survey_year,
    CAST(substr(time, 9, 2) AS INTEGER) // 3 AS survey_quarter,
    indicator,
    cat01 AS horizon_code,
    cat01_metadata->>'$.name' AS horizon,
    cat02 AS size_code,
    cat02_metadata->>'$.name' AS size,
    cat03 AS industry_code,
    cat03_metadata->>'$.name' AS industry_name,
    TRY_CAST(cat03_metadata->>'$.level' AS INTEGER) AS industry_level,
    value
FROM unioned
