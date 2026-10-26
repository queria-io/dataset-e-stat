-- 広域連合・一部事務組合を構成する市町村 (seeds/kaigo_insurance_union_member.csv)。
-- 原典に構成市町村は無いので、最新年度の時点で手で持つ。正しさは
-- tests/kaigo_insurance_union_member_is_exhaustive.sql が最新年度の保険者の一覧と
-- 突き合わせて押さえる。
SELECT
    u.insurer_name,
    m.pref_code AS prefecture_code,
    m.pref_name AS prefecture_name,
    u.area_code,
    coalesce(m.municipality_name, m.designated_city_name) AS municipality_name
FROM {{ ref('kaigo_insurance_union_member') }} u
LEFT JOIN {{ ref('municipality') }} m ON m.area_code = u.area_code
