{# 経済産業省企業活動基本調査の2010〜2019年調査の行に、2020年以降の表のコードと名前を当てる。
   stg_enterprise_activity_legacy が読み分けた表側を、stg_enterprise_activity（2020年以降の調査）と
   同じ列にそろえる。公開せず、読む側の mart に展開する。 #}
{{ config(materialized='ephemeral') }}

WITH capital_codes AS (
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
    n.measure_code,
    n.measure,
    n.unit,
    n.value
FROM {{ ref('stg_enterprise_activity_legacy') }} n
LEFT JOIN capital_codes c ON c.breakdown_name = n.breakdown_name_raw AND n.kind IN ('capital_balance', 'capital_business')
LEFT JOIN current_names cn ON cn.industry_code = n.major_code
LEFT JOIN prefecture_names pn ON pn.breakdown_code = n.breakdown_key AND n.kind = 'prefecture'
LEFT JOIN subsidiary_codes sc ON sc.breakdown_name = translate(n.breakdown_name_raw, '()', '（）') AND n.kind = 'subsidiary'
