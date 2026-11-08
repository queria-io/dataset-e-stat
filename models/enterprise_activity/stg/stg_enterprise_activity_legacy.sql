{# 経済産業省企業活動基本調査の2010〜2019年調査の表を1つに積み、表側を読み分ける。
   stg_enterprise_activity（2020年以降の調査）と同じ列にそろえる。

   表側の名称は全角空白で区切られ、2020年以降と次の点が違う。
   - 大分類・合計・総合計にはコードが付かない（「製造業」）。中分類・小分類はコードが前に付く
     （「090　食料品製造業」）。コードの無い名前は2020年以降の表のコードに当てる（17通り）
   - 年度は総括表の行と、全体の過去5年度の行（「平成21年度」だけの行）にしか付かない。
     ほかの表の行はその調査の実績の年度（調査年の前年度）
   - 都道府県は「01　北海道」（2010年は「01 北　海　道」）、資本金規模は「3千万円～5千万円未満」
     （2010年は全角数字と空白入り）。どちらも内訳の無い行は全体（全国・計）
   - 子会社の表は「親会社の産業　子会社の業種」で、子会社の業種の無い行は全業種
   表頭（測定項目）は2020年以降と数と並びが同じなので、並び順で2025年調査の測定項目に当てる。 #}
WITH unioned AS (
    SELECT 'summary' AS kind, 2010 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2010') }}
    UNION ALL
    SELECT 'summary' AS kind, 2011 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2011') }}
    UNION ALL
    SELECT 'summary' AS kind, 2012 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2012') }}
    UNION ALL
    SELECT 'summary' AS kind, 2013 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2013') }}
    UNION ALL
    SELECT 'summary' AS kind, 2014 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2014') }}
    UNION ALL
    SELECT 'summary' AS kind, 2015 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2015') }}
    UNION ALL
    SELECT 'summary' AS kind, 2016 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2016') }}
    UNION ALL
    SELECT 'summary' AS kind, 2017 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2017') }}
    UNION ALL
    SELECT 'summary' AS kind, 2018 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2018') }}
    UNION ALL
    SELECT 'summary' AS kind, 2019 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_summary_2019') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2010 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2010') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2011 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2011') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2012 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2012') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2013 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2013') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2014 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2014') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2015 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2015') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2016 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2016') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2017 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2017') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2018 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2018') }}
    UNION ALL
    SELECT 'prefecture' AS kind, 2019 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_prefecture_2019') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2010 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2010') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2011 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2011') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2012 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2012') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2013 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2013') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2014 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2014') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2015 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2015') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2016 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2016') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2017 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2017') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2018 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2018') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, 2019 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_balance_2019') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2010 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2010') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2011 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2011') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2012 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2012') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2013 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2013') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2014 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2014') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2015 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2015') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2016 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2016') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2017 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2017') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2018 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2018') }}
    UNION ALL
    SELECT 'capital_business' AS kind, 2019 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_capital_business_2019') }}
    UNION ALL
    SELECT 'research' AS kind, 2010 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2010') }}
    UNION ALL
    SELECT 'research' AS kind, 2011 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2011') }}
    UNION ALL
    SELECT 'research' AS kind, 2012 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2012') }}
    UNION ALL
    SELECT 'research' AS kind, 2013 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2013') }}
    UNION ALL
    SELECT 'research' AS kind, 2014 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2014') }}
    UNION ALL
    SELECT 'research' AS kind, 2015 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2015') }}
    UNION ALL
    SELECT 'research' AS kind, 2016 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2016') }}
    UNION ALL
    SELECT 'research' AS kind, 2017 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2017') }}
    UNION ALL
    SELECT 'research' AS kind, 2018 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2018') }}
    UNION ALL
    SELECT 'research' AS kind, 2019 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_research_2019') }}
    UNION ALL
    SELECT 'foreign' AS kind, 2015 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_foreign_2015') }}
    UNION ALL
    SELECT 'foreign' AS kind, 2016 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_foreign_2016') }}
    UNION ALL
    SELECT 'foreign' AS kind, 2017 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_foreign_2017') }}
    UNION ALL
    SELECT 'foreign' AS kind, 2018 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_foreign_2018') }}
    UNION ALL
    SELECT 'foreign' AS kind, 2019 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_foreign_2019') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2010 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2010') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2011 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2011') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2012 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2012') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2013 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2013') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2014 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2014') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2015 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2015') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2016 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2016') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2017 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2017') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2018 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2018') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, 2019 AS survey_year, cat01_order, cat02, cat02_metadata->>'$.name' AS row_label, value
    FROM {{ ref('raw_enterprise_activity_subsidiary_2019') }}
),

measures AS (
    SELECT kind, cat01 AS measure_code,
        regexp_replace(measure_label, '_[^_]+$', '') AS measure,
        regexp_extract(measure_label, '_([^_]+)$', 1) AS unit,
        row_number() OVER (PARTITION BY kind ORDER BY cat01) - 1 AS cat01_order
    FROM (SELECT DISTINCT * FROM (
    SELECT 'summary' AS kind, cat01, cat01_metadata->>'$.name' AS measure_label
    FROM {{ ref('raw_enterprise_activity_summary_2025') }}
    UNION ALL
    SELECT 'prefecture' AS kind, cat01, cat01_metadata->>'$.name' AS measure_label
    FROM {{ ref('raw_enterprise_activity_prefecture_2025') }}
    UNION ALL
    SELECT 'capital_balance' AS kind, cat01, cat01_metadata->>'$.name' AS measure_label
    FROM {{ ref('raw_enterprise_activity_capital_balance_2025') }}
    UNION ALL
    SELECT 'capital_business' AS kind, cat01, cat01_metadata->>'$.name' AS measure_label
    FROM {{ ref('raw_enterprise_activity_capital_business_2025') }}
    UNION ALL
    SELECT 'research' AS kind, cat01, cat01_metadata->>'$.name' AS measure_label
    FROM {{ ref('raw_enterprise_activity_research_2025') }}
    UNION ALL
    SELECT 'foreign' AS kind, cat01, cat01_metadata->>'$.name' AS measure_label
    FROM {{ ref('raw_enterprise_activity_foreign_2025') }}
    UNION ALL
    SELECT 'subsidiary' AS kind, cat01, cat01_metadata->>'$.name' AS measure_label
    FROM {{ ref('raw_enterprise_activity_subsidiary_2025') }}
    ))
),

tokens AS (
    SELECT
        *,
        string_split(
            trim(regexp_replace(
                replace(translate(row_label, '０１２３４５６７８９（）', '0123456789()'), '　', ' '),
                '\s+', ' ', 'g'
            )),
            ' '
        ) AS t
    FROM unioned
),

{# 先頭から産業を1つ読む。コード（3桁の数字）が先にあれば次の語までを1つの産業にする #}
parsed AS (
    SELECT
        *,
        regexp_full_match(t[1], '[0-9]{3}') AS first_coded,
        CASE WHEN regexp_full_match(t[1], '[0-9]{3}') THEN 3 ELSE 2 END AS rest_start
    FROM tokens
),

split AS (
    SELECT
        kind,
        survey_year,
        cat01_order,
        value,
        t,
        CASE WHEN first_coded THEN t[1] END AS industry_code_raw,
        CASE WHEN first_coded THEN t[2] ELSE t[1] END AS industry_name,
        t[rest_start:] AS rest
    FROM parsed
    -- 全体の過去5年度の行（「平成21年度」だけの行）は、総括表以外では使わない
    WHERE NOT (kind <> 'summary' AND len(t) = 1 AND regexp_full_match(t[1], '平成[0-9]+年度'))
),

details AS (
    SELECT
        *,
        CASE
            WHEN kind = 'summary' THEN 1988 + CAST(regexp_extract(rest[-1], '平成([0-9]+)年度', 1) AS INTEGER)
            ELSE survey_year - 1
        END AS fiscal_year,
        CASE kind
            WHEN 'prefecture' THEN CASE WHEN len(rest) = 0 THEN '00' ELSE lpad(rest[1], 2, '0') END
            WHEN 'capital_balance' THEN CASE WHEN len(rest) = 0 THEN '計' ELSE array_to_string(rest, '') END
            WHEN 'capital_business' THEN CASE WHEN len(rest) = 0 THEN '計' ELSE array_to_string(rest, '') END
            WHEN 'subsidiary' THEN CASE WHEN len(rest) = 0 THEN NULL WHEN regexp_full_match(rest[1], '[0-9]{3}') THEN rest[1] END
        END AS breakdown_key,
        CASE kind
            WHEN 'prefecture' THEN CASE WHEN len(rest) = 0 THEN '計' ELSE array_to_string(rest[2:], '') END
            WHEN 'capital_balance' THEN CASE WHEN len(rest) = 0 THEN '計' ELSE array_to_string(rest, '') END
            WHEN 'capital_business' THEN CASE WHEN len(rest) = 0 THEN '計' ELSE array_to_string(rest, '') END
            WHEN 'subsidiary' THEN CASE WHEN len(rest) = 0 THEN NULL WHEN regexp_full_match(rest[1], '[0-9]{3}') THEN rest[2] ELSE rest[1] END
        END AS breakdown_name_raw
    FROM split
),

{# コードの付かない産業名を2020年以降の表のコードに当てる #}
named AS (
    SELECT
        *,
        {{ e_stat_enterprise_activity_major_code('industry_name') }} AS major_code
    FROM details
),

capital_codes AS (
    SELECT DISTINCT breakdown_name, breakdown_code
    FROM {{ ref('stg_enterprise_activity') }}
    WHERE kind IN ('capital_balance', 'capital_business')
),

{# 子会社の業種の大分類は、親会社の産業と区分が違う（J 金融業、保険業、R サービス業 など）。
   2020年以降の子会社の表で同じ名前に付いたコードを引く #}
{# 名前の書き方が年で揺れるもの（2010年調査の「和歌山」、「クレジットカード業・割賦金融業」）を
   2020年以降の表の名前にそろえる。コードで引く #}
current_names AS (
    SELECT industry_code, any_value(industry_name ORDER BY survey_year DESC) AS industry_name
    FROM {{ ref('stg_enterprise_activity') }}
    GROUP BY industry_code
),

prefecture_names AS (
    SELECT breakdown_code, any_value(breakdown_name ORDER BY survey_year DESC) AS breakdown_name
    FROM {{ ref('stg_enterprise_activity') }}
    WHERE kind = 'prefecture'
    GROUP BY breakdown_code
),

subsidiary_codes AS (
    SELECT DISTINCT breakdown_name, breakdown_code
    FROM {{ ref('stg_enterprise_activity') }}
    WHERE kind = 'subsidiary' AND NOT regexp_full_match(breakdown_code, '[0-9]{3}')
)

SELECT
    n.kind,
    n.survey_year,
    n.fiscal_year,
    coalesce(n.industry_code_raw, n.major_code) AS industry_code,
    -- コードの付かない大分類などは2020年以降の表の名前にそろえる。ほかは括弧を全角に戻す
    CASE WHEN n.major_code IS NOT NULL THEN coalesce(cn.industry_name, translate(n.industry_name, '()', '（）'))
        ELSE translate(n.industry_name, '()', '（）') END AS industry_name,
    CASE
        WHEN n.kind = 'prefecture' THEN n.breakdown_key
        WHEN n.kind IN ('capital_balance', 'capital_business') THEN c.breakdown_code
        -- 子会社の業種の無い行は全業種。2020年以降の表と同じく、親会社が総合計なら 総合計、ほかは 000
        WHEN n.kind = 'subsidiary' AND n.breakdown_name_raw IS NULL THEN
            CASE WHEN coalesce(n.industry_code_raw, n.major_code) = '総合計' THEN '総合計' ELSE '000' END
        WHEN n.kind = 'subsidiary' THEN coalesce(n.breakdown_key, sc.breakdown_code)
    END AS breakdown_code,
    CASE
        WHEN n.kind = 'subsidiary' THEN coalesce(
            translate(n.breakdown_name_raw, '()', '（）'),
            CASE WHEN coalesce(n.industry_code_raw, n.major_code) = '総合計' THEN '総合計' ELSE '合計' END
        )
        WHEN n.kind = 'prefecture' THEN coalesce(pn.breakdown_name, n.breakdown_name_raw)
        ELSE n.breakdown_name_raw
    END AS breakdown_name,
    m.measure_code,
    m.measure,
    m.unit,
    n.value
FROM named n
LEFT JOIN measures m ON m.kind = n.kind AND m.cat01_order = n.cat01_order
LEFT JOIN capital_codes c ON c.breakdown_name = n.breakdown_name_raw AND n.kind IN ('capital_balance', 'capital_business')
LEFT JOIN current_names cn ON cn.industry_code = n.major_code
LEFT JOIN prefecture_names pn ON pn.breakdown_code = n.breakdown_key AND n.kind = 'prefecture'
LEFT JOIN subsidiary_codes sc ON sc.breakdown_name = translate(n.breakdown_name_raw, '()', '（）') AND n.kind = 'subsidiary'
