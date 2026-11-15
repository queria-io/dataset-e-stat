-- code.municipality_name の整合を検証する。結果が0行ならテスト成功。
--
-- 1. 同じコードの有効期間が重ならない
-- 2. 同じ日に、同じ都道府県で同じ qualified_name が 2 つのコードを指さない。
--    北方領土の 6 村 (01695〜01700) は除く。泊村 (01696) は古宇郡泊村 (01403) と同じ名前で、
--    北海道は郡名を持たないので qualified_name でも分けられない
-- 3. 今も有効な行の数が、今の一覧の行数と同じ (区間のまとめ方で行を落としていない)
-- 4. 今のコード (current_area_code) は今も有効なコードを指す
-- 5. 合併で無くなったコードの 95% 以上に今のコードが付く (引き継ぎ先の読み取りが崩れたら落ちる)
WITH m AS (SELECT * FROM {{ ref('municipality_name') }}),

current_rows AS (
    SELECT DISTINCT area_code FROM m WHERE valid_to IS NULL
),

overlap AS (
    SELECT 'overlap: ' || a.area_code || ' ' || a.valid_from AS problem
    FROM m a
    JOIN m b
        ON a.area_code = b.area_code
        AND a.valid_from < b.valid_from
        AND (a.valid_to IS NULL OR a.valid_to > b.valid_from)
),

ambiguous AS (
    SELECT 'ambiguous: ' || a.pref_name || a.qualified_name || ' ' || a.valid_from AS problem
    FROM m a
    JOIN m b
        ON a.pref_name = b.pref_name
        AND a.qualified_name = b.qualified_name
        AND a.area_code < b.area_code
        AND NOT (a.area_code BETWEEN '01695' AND '01700' OR b.area_code BETWEEN '01695' AND '01700')
        AND a.valid_from < coalesce(b.valid_to, DATE '9999-12-31')
        AND b.valid_from < coalesce(a.valid_to, DATE '9999-12-31')
),

latest AS (
    SELECT count(*) AS n
    FROM {{ ref('raw_municipality_history_snapshot') }}
    WHERE as_of = (SELECT max(as_of) FROM {{ ref('raw_municipality_history_snapshot') }})
),

current_count AS (
    SELECT 'current rows: ' || (SELECT count(*) FROM m WHERE valid_to IS NULL) || ' <> ' || n AS problem
    FROM latest
    WHERE n <> (SELECT count(*) FROM m WHERE valid_to IS NULL)
),

dangling AS (
    SELECT DISTINCT 'current_area_code not current: ' || area_code || ' -> ' || current_area_code AS problem
    FROM m
    WHERE current_area_code IS NOT NULL
        AND current_area_code NOT IN (SELECT area_code FROM current_rows)
),

coverage AS (
    SELECT 'current_area_code coverage: ' || round(avg((current_area_code IS NOT NULL)::INT), 3) AS problem
    FROM (SELECT DISTINCT area_code, current_area_code FROM m WHERE area_code NOT IN (SELECT area_code FROM current_rows))
    HAVING avg((current_area_code IS NOT NULL)::INT) < 0.95
)

SELECT problem FROM overlap
UNION ALL SELECT problem FROM ambiguous
UNION ALL SELECT problem FROM current_count
UNION ALL SELECT problem FROM dangling
UNION ALL SELECT problem FROM coverage
