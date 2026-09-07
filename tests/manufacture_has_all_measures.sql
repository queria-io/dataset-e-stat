-- municipality_industry の集計項目・収録年・金額の実績年が揃っていることを検証する。
-- 結果が0行ならテスト成功。
--
-- mart は原典の集計項目コードで列を開いている。コードは2014年までの9桁(010000000 など)と
-- 2017年以降の8桁(32000070 など)で体系が違い、両方を拾っている。e-Stat がどちらかを
-- 振り直すと該当の列が丸ごと NULL になるが、行数も粒度も変わらないので他のテストでは
-- 気づけない。年ごとに代表行を見る。
--
-- 対応付けていない集計項目コードは mart の GROUP BY で痕跡なく畳まれるので、stg の
-- コードの顔ぶれも年ごとに突き合わせる。列が NULL になる壊れ方と、原典に項目が
-- 増減する壊れ方は別物で、代表行の NULL 検査では後者を捉えられない。
--
-- 年は固定リストから外側結合で引く。mart 側から GROUP BY すると、年が丸ごと落ちた
-- ときにグループそのものが生まれず、0行 = 合格を返して素通りする。
--
-- その他収入額と有形固定資産年末現在高は2017年以降の統計表に無いので、2014年までの年
-- だけで見る。金額の項目は秘匿で NULL が入るため、秘匿の起きない都道府県の製造業計を
-- 代表にする。

{% set survey_years = [2008, 2009, 2010, 2012, 2013, 2014, 2017, 2018, 2019, 2020] %}
{% set old_items = [
    '010000000', '010010000', '010020000', '020000000', '030000000',
    '040000000', '050000000', '050010000', '060000000', '070000000'
] %}
{% set new_items = [
    '32000070', '32000080', '32000090', '32000095',
    '32000100', '32000110', '32000120', '32000140'
] %}

WITH expected_years AS (
    SELECT UNNEST({{ survey_years }}::INTEGER[]) AS survey_year
),

-- 愛知県の製造業計。製造品出荷額等が全国で最も大きい県で、どの年も秘匿されない。
representative AS (
    SELECT *
    FROM {{ ref('municipality_industry') }}
    WHERE area = '23000' AND industry_code = '00'
),

items_by_year AS (
    SELECT survey_year, LIST_SORT(ARRAY_AGG(DISTINCT cat01)) AS item_codes
    FROM {{ ref('stg_manufacture_municipality') }}
    GROUP BY survey_year
)

SELECT '収録年が原典と違う' AS violation,
    ARRAY_TO_STRING(LIST_SORT(ARRAY_AGG(DISTINCT CAST(survey_year AS VARCHAR))), ',') AS detail
FROM {{ ref('municipality_industry') }}
HAVING LIST_SORT(ARRAY_AGG(DISTINCT survey_year)) <> LIST_SORT({{ survey_years }}::INTEGER[])
UNION ALL
SELECT '代表行（愛知県・製造業計）が年に1件でない', CAST(e.survey_year AS VARCHAR)
FROM expected_years e
LEFT JOIN representative r ON r.survey_year = e.survey_year
GROUP BY e.survey_year
HAVING COUNT(r.area) <> 1
UNION ALL
SELECT '代表行に欠けている測定項目がある', CAST(survey_year AS VARCHAR)
FROM representative
WHERE establishments IS NULL
    OR establishments_30_to_299 IS NULL
    OR establishments_300_or_more IS NULL
    OR employees IS NULL
    OR cash_earnings_10k_yen IS NULL
    OR material_cost_10k_yen IS NULL
    OR shipment_value_10k_yen IS NULL
    OR gross_value_added_10k_yen IS NULL
UNION ALL
SELECT '2014年までにしかない項目が代表行で欠けている', CAST(survey_year AS VARCHAR)
FROM representative
WHERE survey_year <= 2014
    AND (other_income_10k_yen IS NULL OR tangible_fixed_assets_10k_yen IS NULL)
UNION ALL
SELECT '2017年以降に無いはずの項目が入っている', CAST(survey_year AS VARCHAR)
FROM {{ ref('municipality_industry') }}
WHERE survey_year >= 2017
    AND (other_income_10k_yen IS NOT NULL OR tangible_fixed_assets_10k_yen IS NOT NULL)
UNION ALL
SELECT '集計項目のコードが原典と違う',
    CAST(survey_year AS VARCHAR) || ' ' || ARRAY_TO_STRING(item_codes, ',')
FROM items_by_year
WHERE item_codes <> CASE
    WHEN survey_year <= 2014 THEN LIST_SORT({{ old_items }}::VARCHAR[])
    ELSE LIST_SORT({{ new_items }}::VARCHAR[])
END
UNION ALL
-- 2017年調査から調査期日が翌年6月1日に変わり、金額は前年1〜12月の実績になった。
-- この対応が崩れると、金額の時系列が1年ずれたまま黙って通る。
SELECT '金額の実績年が調査年と対応していない', CAST(survey_year AS VARCHAR)
FROM {{ ref('municipality_industry') }}
WHERE amount_reference_year <> CASE
    WHEN survey_year <= 2014 THEN survey_year
    ELSE survey_year - 1
END
