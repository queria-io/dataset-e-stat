-- 介護保険事業状況報告の保険者別の表 (kaigo_insurance.insured_persons・certified_persons)
-- の整合を検証する。結果が0行ならテスト成功。
--
-- 1. 保険者の行に都道府県コードが付いている (都道府県名の表記が変わると NULL が混ざる)
-- 2. 保険者の合計が全国の行に一致する (2001年度は全国の行が無いので外す)。
--    列の当てはめがずれると、合計の合わない列が出る
-- 3. 要介護度の内訳の合計が「合計」に一致する (小計の列を取り違えると合わない)
-- 4. 認定者数の総数 = 第1号 + 第2号、第1号 = 年齢の内訳の合計
-- 5. 最新年度の市区町村の保険者がすべて code.municipality に当たる (合併で無くなった
--    市町村が当たらないのは過去の年度だけのはず)
-- 6. 保険者が年度ごとに 1 行 (名前で code.municipality に当てるとき、同じ都道府県に
--    同じ名前が 2 つあると行が増える)

WITH insurers AS (
    SELECT fiscal_year, prefecture_name, insurer_name, count(*) AS n
    FROM {{ ref('stg_kaigo_insurance_insurer') }}
    GROUP BY ALL
),

insured AS (
    SELECT * FROM {{ ref('insured_persons') }}
),

certified AS (
    SELECT * FROM {{ ref('certified_persons') }}
),

latest AS (
    SELECT max(fiscal_year) AS fiscal_year FROM insured
),

insured_totals AS (
    SELECT
        fiscal_year,
        category,
        sum(value) FILTER (WHERE insurer_kind <> 'nationwide') AS insurers,
        max(value) FILTER (WHERE insurer_kind = 'nationwide') AS nationwide
    FROM insured
    GROUP BY ALL
),

certified_totals AS (
    SELECT
        fiscal_year,
        insured_category,
        age_group,
        care_level,
        sum(value) FILTER (WHERE insurer_kind <> 'nationwide') AS insurers,
        max(value) FILTER (WHERE insurer_kind = 'nationwide') AS nationwide
    FROM certified
    GROUP BY ALL
),

levels AS (
    SELECT
        fiscal_year,
        prefecture_name,
        insurer_name,
        insured_category,
        age_group,
        sum(value) FILTER (WHERE care_level <> '合計') AS parts,
        max(value) FILTER (WHERE care_level = '合計') AS total
    FROM certified
    GROUP BY ALL
),

groups AS (
    SELECT
        fiscal_year,
        prefecture_name,
        insurer_name,
        care_level,
        max(value) FILTER (WHERE insured_category = '総数') AS total,
        max(value) FILTER (WHERE insured_category = '第1号被保険者' AND age_group IS NULL) AS first,
        sum(value) FILTER (WHERE insured_category = '第1号被保険者' AND age_group IS NOT NULL) AS ages,
        max(value) FILTER (WHERE insured_category = '第2号被保険者') AS second
    FROM certified
    GROUP BY ALL
)

SELECT 'insured prefecture_code is null' AS failure, fiscal_year, insurer_name AS detail
FROM insured WHERE insurer_kind <> 'nationwide' AND prefecture_code IS NULL
UNION ALL
SELECT 'certified prefecture_code is null', fiscal_year, insurer_name
FROM certified WHERE insurer_kind <> 'nationwide' AND prefecture_code IS NULL
UNION ALL
SELECT 'insured insurers do not add up to nationwide', fiscal_year, category
FROM insured_totals
WHERE fiscal_year > 2001 AND insurers IS DISTINCT FROM nationwide
UNION ALL
SELECT 'certified insurers do not add up to nationwide', fiscal_year,
    concat_ws(' ', insured_category, age_group, care_level)
FROM certified_totals
WHERE fiscal_year > 2001 AND insurers IS DISTINCT FROM nationwide
UNION ALL
SELECT 'care levels do not add up to 合計', fiscal_year,
    concat_ws(' ', prefecture_name, insurer_name, insured_category, age_group)
FROM levels WHERE parts IS DISTINCT FROM total
UNION ALL
SELECT '総数 is not 第1号 + 第2号', fiscal_year, concat_ws(' ', prefecture_name, insurer_name, care_level)
FROM groups WHERE total IS DISTINCT FROM first + second
UNION ALL
SELECT '第1号 is not the sum of age groups', fiscal_year, concat_ws(' ', prefecture_name, insurer_name, care_level)
FROM groups WHERE first IS DISTINCT FROM ages
UNION ALL
SELECT 'latest municipal insurer has no area_code', i.fiscal_year, i.prefecture_name || ' ' || i.insurer_name
FROM insured i JOIN latest l USING (fiscal_year)
WHERE i.insurer_kind = 'municipality' AND i.area_code IS NULL AND i.category = '計'
UNION ALL
SELECT 'insurer matched more than once', fiscal_year, prefecture_name || ' ' || insurer_name
FROM insurers WHERE n > 1
