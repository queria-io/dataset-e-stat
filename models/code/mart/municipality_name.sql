-- 市区町村の名前から標準地域コードを引くための表。1 行 = 1 つのコードの、1 つの名前の有効期間。
--
-- e-Stat「市区町村を探す」の一覧を 1970-04-01 と廃置分合等の施行日ごとに取ったもの
-- (stg_municipality_history_snapshot) を、同じコード・同じ名前が続く区間ごとにまとめる。
-- 一覧は施行日ごとにしか取っていないので、区間の境目は必ずどれかの施行日になる。
WITH RECURSIVE dates AS (
    SELECT as_of, row_number() OVER (ORDER BY as_of) AS i
    FROM (SELECT DISTINCT as_of FROM {{ ref('stg_municipality_history_snapshot') }})
),

snapshot AS (
    SELECT s.*, d.i
    FROM {{ ref('stg_municipality_history_snapshot') }} s
    JOIN dates d USING (as_of)
),

-- 同じコード・同じ名前が続けて現れる区間に、同じ番号を振る
islands AS (
    SELECT
        *,
        i - row_number() OVER (
            PARTITION BY area_code, pref_name, parent_name, parent_kana, name, kana, area_kind ORDER BY i
        ) AS island
    FROM snapshot
),

spans AS (
    SELECT
        area_code,
        pref_name,
        parent_name,
        parent_kana,
        name,
        kana,
        area_kind,
        min(i) AS first_i,
        max(i) AS last_i
    FROM islands
    GROUP BY area_code, pref_name, parent_name, parent_kana, name, kana, area_kind, island
),

latest AS (
    SELECT max(i) AS i FROM dates
),

current_codes AS (
    SELECT DISTINCT area_code FROM snapshot WHERE i = (SELECT i FROM latest)
),

-- 一覧から消えたコードの、消えた日 (次の一覧の日)
ended AS (
    SELECT s.area_code, s.last_i, d.as_of AS ended_on
    FROM (SELECT area_code, max(i) AS last_i FROM snapshot GROUP BY area_code) s
    JOIN dates d ON d.i = s.last_i + 1
),

-- 消えた日に施行された廃置分合等のうち、改正事由に消えたコードを含むものの、ほかのコード。
-- 優先順: その日に有効で同じ名前のコード (郡の区域変更) → その日に有効なコード →
-- 同じ日に消えたコード (同じ日に編入と市制施行が続いたとき。瓜連町 → 那珂町 → 那珂市) →
-- 区でないコードにとっての、その日に有効な区。政令指定都市の施行では市の行を区より先に取り、
-- 区だけが挙がる既存の区への編入 (京北町 → 右京区) では区を取る
candidates AS (
    SELECT
        e.area_code,
        c.area_code AS next_code,
        CASE
            WHEN v.area_code IS NULL THEN 2
            WHEN x.area_kind <> 'ward' AND v.area_kind = 'ward' THEN 3
            WHEN v.name = x.name THEN 0
            ELSE 1
        END AS priority
    FROM ended e
    JOIN snapshot x ON x.area_code = e.area_code AND x.i = e.last_i
    JOIN {{ ref('stg_municipality_history_event') }} c
        ON c.effective_date = e.ended_on
        AND contains(c.reason, '(' || e.area_code || ')')
        AND c.area_code <> e.area_code
    LEFT JOIN snapshot v ON v.as_of = e.ended_on AND v.area_code = c.area_code
    LEFT JOIN ended g ON g.area_code = c.area_code AND g.ended_on = e.ended_on
    WHERE v.area_code IS NOT NULL OR g.area_code IS NOT NULL
),

successor AS (
    SELECT DISTINCT area_code, next_code
    FROM candidates
    WHERE (area_code, priority) IN (SELECT area_code, min(priority) FROM candidates GROUP BY area_code)
),

-- 引き継ぎ先を今のコードまでたどる。同じ日に消えたコードどうしは互いを候補にするので、
-- 回数で打ち切る
chain AS (
    SELECT area_code, next_code, 1 AS depth FROM successor
    UNION
    SELECT c.area_code, s.next_code, c.depth + 1
    FROM chain c
    JOIN successor s ON s.area_code = c.next_code
    WHERE c.depth < 10
),

-- たどり着く今のコードが 1 つに決まるときだけ付ける (分割などで 2 つ以上あるときは付けない)
current_code AS (
    SELECT area_code, area_code AS current_area_code FROM current_codes
    UNION ALL
    SELECT area_code, any_value(next_code)
    FROM chain
    WHERE next_code IN (SELECT area_code FROM current_codes)
    GROUP BY area_code
    HAVING count(DISTINCT next_code) = 1
)

SELECT
    s.name,
    s.kana,
    s.parent_name,
    s.parent_kana,
    coalesce(s.parent_name, '') || s.name AS qualified_name,
    s.pref_name,
    left(s.area_code, 2) AS pref_code,
    s.area_code,
    {{ local_government_code('s.area_code') }} AS lg_code,
    s.area_kind,
    f.as_of AS valid_from,
    t.as_of AS valid_to,
    cc.current_area_code
FROM spans s
JOIN dates f ON f.i = s.first_i
LEFT JOIN dates t ON t.i = s.last_i + 1
LEFT JOIN current_code cc USING (area_code)
