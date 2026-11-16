SELECT
    aid AS id,
    -- 政府統計・作成機関
    stat_name__acode AS stat_code,
    stat_name__x AS stat_name,
    gov_org__acode AS gov_org_code,
    gov_org__x AS gov_org_name,
    -- 統計名称
    statistics_name,
    statistics_name_spec__tabulation_category AS tabulation_category,
    CONCAT_WS(
        ' > ',
        NULLIF(statistics_name_spec__tabulation_sub_category1, ''),
        NULLIF(statistics_name_spec__tabulation_sub_category2, ''),
        NULLIF(statistics_name_spec__tabulation_sub_category3, ''),
        NULLIF(statistics_name_spec__tabulation_sub_category4, ''),
        NULLIF(statistics_name_spec__tabulation_sub_category5, '')
    ) AS tabulation_sub_category,
    -- 統計表
    COALESCE(NULLIF(title, ''), title__x, title_spec__table_name) AS title,
    title__ano AS table_number,
    title_spec__table_category AS table_category,
    title_spec__table_name AS table_name,
    title_spec__table_explanation AS table_explanation,
    CONCAT_WS(
        ' > ',
        NULLIF(title_spec__table_sub_category1, ''),
        NULLIF(title_spec__table_sub_category2, ''),
        NULLIF(title_spec__table_sub_category3, '')
    ) AS table_sub_category,
    -- 分野
    main_category__acode AS main_category_code,
    main_category__x AS main_category,
    sub_category__acode AS sub_category_code,
    sub_category__x AS sub_category,
    -- 日付・その他
    cycle,
    survey_date,
    open_date,
    updated_date,
    small_area,
    collect_area,
    overall_total_number
FROM {{ ref('raw_stats_list') }}
