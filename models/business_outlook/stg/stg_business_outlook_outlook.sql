{# 法人企業景気予測調査の売上高・経常利益・設備投資の見通し（金額と前年同期比）を1つに積む。

   原典の時期は調査期から見た相対の年度（前年度・当年度・翌年度とその上期・下期）なので、
   実際の年度に直す。1〜3月期の調査では当年度はその3月に終わる年度、4〜12月期の調査では
   その年の4月に始まる年度。

   翌年度の見通しは1〜3月期の調査だけにあり、当年度の見通しの表と別の表になっている。
   1〜3月期の調査では同じ年度（当年度）が両方の表に出るが、値は一致しない。どちらの表の行かを
   outlook_table に残す。 #}
WITH unioned AS (
    SELECT '当年度見通し' AS outlook_table, '売上高・経常利益' AS item_group,
        tab, tab_metadata, cat01, cat02, cat02_metadata, cat04, cat04_metadata, time, time_metadata, unit, value
    FROM {{ ref('raw_business_outlook_sales_profit_current') }}
    UNION ALL
    SELECT '当年度見通し', '設備投資',
        tab, tab_metadata, cat01, cat02, cat02_metadata, cat04, cat04_metadata, time, time_metadata, unit, value
    FROM {{ ref('raw_business_outlook_investment_current') }}
    UNION ALL
    SELECT '翌年度見通し', '売上高・経常利益',
        tab, tab_metadata, cat01, cat02, cat02_metadata, cat04, cat04_metadata, time, time_metadata, unit, value
    FROM {{ ref('raw_business_outlook_sales_profit_next') }}
    UNION ALL
    SELECT '翌年度見通し', '設備投資',
        tab, tab_metadata, cat01, cat02, cat02_metadata, cat04, cat04_metadata, time, time_metadata, unit, value
    FROM {{ ref('raw_business_outlook_investment_next') }}
),

periods AS (
    SELECT
        *,
        CAST(substr(time, 1, 4) AS INTEGER) AS survey_year,
        CAST(substr(time, 9, 2) AS INTEGER) // 3 AS survey_quarter,
        -- 時期のコード: 10/20/30=前年度の上期・下期・通期、40/50/60=当年度、70/80/90=翌年度
        (CAST(cat01 AS INTEGER) - 10) // 30 - 1 AS year_offset,
        CASE CAST(cat01 AS INTEGER) % 30 WHEN 10 THEN '上期' WHEN 20 THEN '下期' ELSE '通期' END AS half
    FROM unioned
)

SELECT
    time AS survey_time,
    replace(time_metadata->>'$.name', '～', '〜') AS survey_name,
    survey_year,
    survey_quarter,
    outlook_table,
    (survey_year - CASE WHEN survey_quarter = 1 THEN 1 ELSE 0 END) + year_offset AS fiscal_year,
    half,
    cat02 AS industry_code,
    cat02_metadata->>'$.name' AS industry_name,
    TRY_CAST(cat02_metadata->>'$.level' AS INTEGER) AS industry_level,
    cat04_metadata->>'$.name' AS item,
    tab_metadata->>'$.name' AS measure,
    unit,
    value
FROM periods
