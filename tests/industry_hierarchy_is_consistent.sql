-- code.industry の階層が食い違っている行を検出。
-- 結果が0行ならテスト成功。

-- 改定の中でコードが重複している
SELECT
    'duplicate_code' AS violation,
    revision,
    code
FROM {{ ref('industry') }}
GROUP BY revision, code
HAVING COUNT(*) > 1

UNION ALL

-- コードの書式が階層と合わない
SELECT
    'code_format_mismatch',
    revision,
    code
FROM {{ ref('industry') }}
WHERE NOT regexp_full_match(
    code,
    CASE level
        WHEN 'major' THEN '[A-Z]'
        WHEN 'middle' THEN '[0-9]{2}'
        WHEN 'minor' THEN '[0-9]{3}'
        WHEN 'detail' THEN '[0-9]{4}'
    END
)

UNION ALL

-- 親が同じ改定の1つ上の階層に無い（大分類は親を持たない）
SELECT
    'parent_not_found',
    c.revision,
    c.code
FROM {{ ref('industry') }} c
LEFT JOIN {{ ref('industry') }} p
    ON p.revision = c.revision
    AND p.code = c.parent_code
    AND p.level = CASE c.level
        WHEN 'middle' THEN 'major'
        WHEN 'minor' THEN 'middle'
        WHEN 'detail' THEN 'minor'
    END
WHERE (c.level = 'major') <> (c.parent_code IS NULL)
    OR (c.level <> 'major' AND p.code IS NULL)

UNION ALL

-- 大分類のコードが親と食い違う（大分類は自分自身）
SELECT
    'major_code_mismatch',
    c.revision,
    c.code
FROM {{ ref('industry') }} c
LEFT JOIN {{ ref('industry') }} p
    ON p.revision = c.revision
    AND p.code = c.parent_code
WHERE c.major_code IS DISTINCT FROM
    CASE WHEN c.level = 'major' THEN c.code ELSE p.major_code END

UNION ALL

-- 大分類の下に中分類が1つも無い。中分類の親は CSV の並び順から取るので、
-- 並び順が変わると中分類が別の大分類の下に入り、中分類の無い大分類ができる
SELECT
    'major_without_middle',
    j.revision,
    j.code
FROM {{ ref('industry') }} j
WHERE j.level = 'major'
    AND NOT EXISTS (
        SELECT 1
        FROM {{ ref('industry') }} m
        WHERE m.revision = j.revision
            AND m.level = 'middle'
            AND m.parent_code = j.code
    )

UNION ALL

-- 4改定がそろっている
SELECT
    'missing_revision',
    r.revision,
    NULL
FROM (VALUES (2002), (2007), (2013), (2023)) r (revision)
WHERE r.revision NOT IN (SELECT revision FROM {{ ref('industry') }})
