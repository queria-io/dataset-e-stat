-- code スキーマの統計分類（industry 以外）の親子が食い違っている行を検出。
-- 結果が0行ならテスト成功。

{% set tables = [
    'occupation',
    'commodity',
    'icd10',
    'icd10_disease',
    'icd10_cause_of_death',
    'industry_economic_census',
] %}

{% for t in tables %}
{% if not loop.first %}UNION ALL{% endif %}

-- 改定の中でコードが重複している
SELECT '{{ t }}' AS table_name, 'duplicate_code' AS violation, revision, code
FROM {{ ref(t) }}
GROUP BY revision, code
HAVING COUNT(*) > 1

UNION ALL

-- 親が同じ改定に無い
SELECT '{{ t }}', 'parent_not_found', c.revision, c.code
FROM {{ ref(t) }} c
LEFT JOIN {{ ref(t) }} p
    ON p.revision = c.revision AND p.code = c.parent_code
WHERE c.parent_code IS NOT NULL AND p.code IS NULL
{% endfor %}

UNION ALL

-- 根（親の無い行）が最上位の階層だけになっている
SELECT 'occupation', 'root_not_major', revision, code
FROM {{ ref('occupation') }}
WHERE (parent_code IS NULL) <> (level = 'major')

UNION ALL

SELECT 'commodity', 'root_not_major', revision, code
FROM {{ ref('commodity') }}
WHERE (parent_code IS NULL) <> (level = 1)

UNION ALL

SELECT 'icd10', 'root_not_chapter', revision, code
FROM {{ ref('icd10') }}
WHERE (parent_code IS NULL) <> (level = 'chapter')

UNION ALL

SELECT 'industry_economic_census', 'root_not_major', revision, code
FROM {{ ref('industry_economic_census') }}
WHERE (parent_code IS NULL) <> (level = 'major')
