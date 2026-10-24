{# 令和5年住宅・土地統計調査 世帯の年間収入階級(10区分)・住宅の所有の関係(5区分)別主世帯数 (0004021668)。
   tab=表章項目 (主世帯数・1世帯当たり人員など)、cat01=住宅の所有の関係、cat02=年間収入階級。 #}
SELECT
    tab, cat01, cat02, area, time, unit, value,
    cat01_metadata, cat02_metadata, area_metadata
FROM {{ source('estat_source', 'housing_survey_income_tenure') }}
