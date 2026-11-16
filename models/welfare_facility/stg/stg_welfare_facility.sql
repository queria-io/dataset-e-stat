-- 行見出しの都道府県名を正式名にそろえ、印字されていない大分類を補う。
--
-- 都道府県は 2022 年調査まで「青森」、2023 年調査から「青森県」で入る。接尾辞を
-- 補って code.municipality_name の pref_name にそろえる。東京・大阪・京都は「都」
-- 「府」で終わるので、末尾 1 文字で判定する前に名指しで拾う。
-- 標準地域コードは mart で当てる。
WITH named AS (
    SELECT
        *,
        CASE
            WHEN area_kind <> 'prefecture' THEN area_label
            WHEN area_label = '東京' THEN '東京都'
            WHEN area_label IN ('大阪', '京都') THEN area_label || '府'
            WHEN right(area_label, 1) IN ('都', '道', '府', '県') THEN area_label
            ELSE area_label || '県'
        END AS area_name
    FROM {{ ref('raw_welfare_facility') }}
),

-- 定員・在所者数の表は 2014 年調査まで見出しが 1 段しかなく、施設の種類は並ぶが
-- その上の大分類が印字されない。同じ年の別の表が同じ符号に与えている大分類で補う。
-- 補わないと、大分類でまとめた集計が 2011〜2014 年調査の定員・在所者数だけ黙って
-- 落ちる (実測: その 4 年の定員・在所者数は符号を持つ行の全部が空欄)。
-- 符号と大分類の対応は年の中で 1 対 1 で、食い違う符号は無い (実測)。
facility_group AS (
    SELECT DISTINCT survey_year, facility_code, facility_group
    FROM named
    WHERE facility_code IS NOT NULL AND facility_group IS NOT NULL
)

SELECT
    n.survey_year,
    n.area_kind,
    n.area_name,
    n.facility_code,
    n.facility_type,
    -- 符号を持つ行は原典でも大分類の直下にいる (実測: facility_level='type' の行は
    -- 上の段が大分類と一致する)。補った大分類はそのまま 1 つ上の段にもなる。
    COALESCE(n.facility_parent, g.facility_group) AS facility_parent,
    COALESCE(n.facility_group, g.facility_group) AS facility_group,
    n.facility_level,
    n.operator,
    n.survey_form,
    n.measure,
    n.value
FROM named n
LEFT JOIN facility_group g
    ON n.facility_code IS NOT NULL
    AND g.survey_year = n.survey_year
    AND g.facility_code = n.facility_code
