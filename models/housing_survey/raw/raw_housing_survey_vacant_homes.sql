{# 令和5年住宅・土地統計調査 空き家の種類(4区分)・腐朽・破損の有無(2区分)・建て方(2区分)・構造(2区分)別空き家数 (0004021631)。
   tab=表章項目 (空き家数 03-2023 だけ)、cat01=腐朽・破損の有無、cat02=住宅の建て方、
   cat03=建物の構造、cat04=空き家の種類。 #}
SELECT
    tab, cat01, cat02, cat03, cat04, area, time, unit, value,
    cat01_metadata, cat02_metadata, cat03_metadata, cat04_metadata, area_metadata
FROM {{ source('estat_source', 'housing_survey_vacant_homes') }}
