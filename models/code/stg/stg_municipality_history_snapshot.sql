-- 施行日ごとの市区町村コードの一覧 (raw_municipality_history_snapshot) を、名前の列にそろえる。
--
-- 政令指定都市の市の行は、市の名前が親の列に入り、市区町村の列は空なので、市の名前を name にする。
-- 北海道の振興局・支庁は名前に付けて書かないので、親の名前は郡と政令指定都市だけを残す。
-- 東京都の「特別区部」(13100) は 23 区をまとめた集計の行で、市区町村ではないので district にする。
SELECT
    CAST(as_of AS DATE) AS as_of,
    area_code,
    pref_name,
    CASE WHEN name IS NOT NULL AND regexp_matches(parent_name, '(郡|市)$') THEN parent_name END AS parent_name,
    CASE WHEN name IS NOT NULL AND regexp_matches(parent_name, '(郡|市)$') THEN parent_kana END AS parent_kana,
    coalesce(name, parent_name) AS name,
    coalesce(kana, parent_kana) AS kana,
    CASE
        WHEN name IS NULL THEN 'designated_city'
        WHEN name = '特別区部' THEN 'district'
        WHEN parent_name LIKE '%市' THEN 'ward'
        ELSE 'municipality'
    END AS area_kind
FROM {{ ref('raw_municipality_history_snapshot') }}
