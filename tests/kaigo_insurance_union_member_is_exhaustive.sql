-- 広域連合・一部事務組合の構成市町村 (kaigo_insurance.union_member) を、最新年度の
-- 保険者の一覧と突き合わせる。結果が0行ならテスト成功。
--
-- 原典に構成市町村は無く、seeds/kaigo_insurance_union_member.csv に手で持っている。
-- 新しい年度を取り込んで広域連合の加入・脱退があると、ここで止まる。
--
-- 1. 現行の市区町村 (北方領土の 6 村を除く) が、単独の保険者か広域連合のどちらか
--    ちょうど 1 つに入る
-- 2. union_member の広域連合が最新年度の保険者にあり、最新年度の広域連合がすべて
--    union_member にある
-- 3. union_member の市区町村コードが code.municipality にある
--
-- 元表をまだ取り込んでいないカタログ (raw が 0 行) では突き合わせる相手が無いので見ない。

WITH latest AS (
    SELECT max(fiscal_year) AS fiscal_year FROM {{ ref('insured_persons') }}
),

insurers AS (
    SELECT DISTINCT i.prefecture_code, i.insurer_name, i.insurer_kind, i.area_code
    FROM {{ ref('insured_persons') }} i
    JOIN latest l USING (fiscal_year)
    WHERE i.insurer_kind <> 'nationwide'
),

members AS (
    SELECT * FROM {{ ref('union_member') }}
),

coverage AS (
    SELECT area_code FROM insurers WHERE insurer_kind = 'municipality'
    UNION ALL
    SELECT area_code FROM members
),

municipalities AS (
    SELECT area_code, pref_name, coalesce(municipality_name, designated_city_name) AS name
    FROM {{ ref('municipality') }}
    WHERE is_municipality
        -- 北方領土の 6 村 (色丹村・泊村・留夜別村・留別村・紗那村・蘂取村)
        AND area_code NOT BETWEEN '01695' AND '01700'
),

failures AS (
    SELECT 'municipality not covered exactly once' AS failure, m.area_code AS detail, count(c.area_code)::VARCHAR AS n
    FROM municipalities m
    LEFT JOIN coverage c USING (area_code)
    GROUP BY m.area_code
    HAVING count(c.area_code) <> 1
    UNION ALL
    SELECT 'member union not among latest insurers', m.insurer_name, m.area_code
    FROM members m
    WHERE NOT EXISTS (
        SELECT 1 FROM insurers i
        WHERE i.insurer_kind = 'union'
            AND i.insurer_name = m.insurer_name
            AND i.prefecture_code = m.prefecture_code
    )
    UNION ALL
    SELECT 'latest union has no members', i.insurer_name, i.prefecture_code
    FROM insurers i
    WHERE i.insurer_kind = 'union'
        AND NOT EXISTS (
            SELECT 1 FROM members m
            WHERE m.insurer_name = i.insurer_name AND m.prefecture_code = i.prefecture_code
        )
    UNION ALL
    SELECT 'member area_code not in code.municipality', insurer_name, area_code
    FROM members WHERE prefecture_code IS NULL
)

SELECT * FROM failures
WHERE (SELECT fiscal_year FROM latest) IS NOT NULL
