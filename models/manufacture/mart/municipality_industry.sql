{# 集計項目 (cat01) を1行に開く。縦持ちのままだと事業所と人と万円が同じ列に並び、
   絞り込みを忘れた合計が黙って通る。

   集計項目のコードは2014年までと2017年以降で体系が違うので、同じ意味の項目を
   2つのコードで拾う。その他収入額と有形固定資産年末現在高は2017年以降の表に無く、
   その年は NULL になる。

   金額の実績年 (amount_reference_year) を出す。2017年調査から調査期日が12月31日から
   翌年6月1日に変わり、事業所数・従業者数は調査年の6月1日現在、金額は前年1〜12月の
   実績になった。2014年までは12月31日現在と当年1〜12月の実績で、調査年と実績年が同じ。
   同じ1行の中で件数と金額の対象期間がずれるので、金額を年で並べるときはこの列を使う。 #}
SELECT
    survey_year,
    -- 2017年調査以降の金額は前年の実績。件数は survey_year 時点。
    CASE WHEN survey_year <= 2014 THEN survey_year ELSE survey_year - 1 END
        AS amount_reference_year,
    area,
    ANY_VALUE(area_name) AS area_name,
    ANY_VALUE(area_level) AS area_level,
    ANY_VALUE(parent_area) AS parent_area,
    industry_code,
    ANY_VALUE(industry_name) AS industry_name,
    ANY_VALUE(industry_level) AS industry_level,
    CAST(MAX(value) FILTER (WHERE cat01 IN ('010000000', '32000070')) AS BIGINT)
        AS establishments,
    CAST(MAX(value) FILTER (WHERE cat01 IN ('010010000', '32000080')) AS BIGINT)
        AS establishments_30_to_299,
    CAST(MAX(value) FILTER (WHERE cat01 IN ('010020000', '32000090')) AS BIGINT)
        AS establishments_300_or_more,
    CAST(MAX(value) FILTER (WHERE cat01 IN ('020000000', '32000095')) AS BIGINT)
        AS employees,
    CAST(MAX(value) FILTER (WHERE cat01 IN ('030000000', '32000100')) AS BIGINT)
        AS cash_earnings_10k_yen,
    CAST(MAX(value) FILTER (WHERE cat01 IN ('040000000', '32000110')) AS BIGINT)
        AS material_cost_10k_yen,
    CAST(MAX(value) FILTER (WHERE cat01 IN ('050000000', '32000120')) AS BIGINT)
        AS shipment_value_10k_yen,
    CAST(MAX(value) FILTER (WHERE cat01 = '050010000') AS BIGINT)
        AS other_income_10k_yen,
    CAST(MAX(value) FILTER (WHERE cat01 IN ('060000000', '32000140')) AS BIGINT)
        AS gross_value_added_10k_yen,
    CAST(MAX(value) FILTER (WHERE cat01 = '070000000') AS BIGINT)
        AS tangible_fixed_assets_10k_yen
FROM {{ ref('stg_manufacture_municipality') }}
GROUP BY survey_year, area, industry_code
