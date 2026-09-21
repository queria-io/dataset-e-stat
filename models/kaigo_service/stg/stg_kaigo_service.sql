-- 都道府県コードから都道府県名を当てる。
--
-- 行見出しの標準地域コードは調査時点のもので、その後の合併で消えたコードが
-- 混ざる (実測: 2001〜2024年調査に出る 3,785 コードのうち、現行の一覧に残るのは
-- 1,960)。市区町村そのものを code.municipality に当てにいくと平成の大合併の
-- 前後で当たり外れが出るので、年をまたいでも動かない都道府県のコードで結合する。
WITH prefecture AS (
    SELECT pref_code, pref_name
    FROM {{ ref('stg_municipality') }}
    WHERE is_prefecture
)

SELECT
    k.survey_year,
    k.area_code,
    k.area_name,
    k.area_kind,
    k.prefecture_code,
    p.pref_name AS prefecture_name,
    k.facility_type,
    k.survey_form,
    k.measure,
    k.value
FROM {{ ref('raw_kaigo_service') }} k
LEFT JOIN prefecture p ON p.pref_code = k.prefecture_code
