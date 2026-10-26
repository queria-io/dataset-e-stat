-- 年度ごとの保険者の一覧に、都道府県コードと市区町村コードを当てる。
--
-- 原典には保険者番号が無く、都道府県名と保険者名だけが並ぶ。市区町村が単独で
-- 保険者のときは、現行の code.municipality に名前で当てる。「関ヶ原町」と「関ケ原町」
-- のように原典と標準地域コードで小さいヶとケが揺れるので、ケに寄せて比べる。
-- 合併で無くなった市町村は当たらず area_code が NULL になる。
--
-- 広域連合・一部事務組合は名前が市区町村で終わらないので、それで見分ける。
-- 構成する市町村は kaigo_insurance.union_member (最新年度の時点) にある。
WITH insurers AS (
    SELECT DISTINCT fiscal_year, prefecture_name, insurer_name
    FROM {{ ref('raw_kaigo_insurance_insured') }}
    UNION
    SELECT DISTINCT fiscal_year, prefecture_name, insurer_name
    FROM {{ ref('raw_kaigo_insurance_certified') }}
),

municipality AS (
    SELECT
        area_code,
        pref_code,
        replace(coalesce(municipality_name, designated_city_name), 'ヶ', 'ケ') AS name_key
    FROM {{ ref('municipality') }}
    WHERE is_municipality
        -- 北方領土の 6 村は保険者にならない。北海道に泊村が 2 つ (01403・01696) あり、
        -- 外さないと 2008年度まで単独の保険者だった後志の泊村の行が 2 倍になる
        AND area_code NOT BETWEEN '01695' AND '01700'
),

prefecture AS (
    SELECT pref_code, pref_name
    FROM {{ ref('municipality') }}
    WHERE is_prefecture
),

classified AS (
    SELECT
        i.fiscal_year,
        p.pref_code AS prefecture_code,
        i.prefecture_name,
        i.insurer_name,
        CASE
            WHEN i.insurer_name IS NULL THEN 'nationwide'
            WHEN regexp_matches(i.insurer_name, '[市区町村]$') THEN 'municipality'
            ELSE 'union'
        END AS insurer_kind
    FROM insurers i
    LEFT JOIN prefecture p ON p.pref_name = i.prefecture_name
)

SELECT
    c.fiscal_year,
    c.prefecture_code,
    c.prefecture_name,
    c.insurer_name,
    c.insurer_kind,
    m.area_code
FROM classified c
LEFT JOIN municipality m
    ON c.insurer_kind = 'municipality'
    AND m.pref_code = c.prefecture_code
    AND m.name_key = replace(c.insurer_name, 'ヶ', 'ケ')
