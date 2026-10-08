-- municipality_migration_age の年齢5歳階級の和を、municipality_migration の年齢総数と
-- 突き合わせる。結果が0行ならテスト成功。
--
-- 和は総数にちょうどは一致しない。総数には年齢階級のどれにも入らない移動者が含まれ、
-- 和は総数を下回る（2014〜2025年で、全国の差は最大38人・総数の0.003%、都道府県の差は
-- 最大0.41%）。上回ることは無い。そこで「和 <= 総数」と、その差が転入・転出・転入超過の
-- 間で整合すること（転入の差 - 転出の差 = 転入超過の差）を見る。階級が丸ごと欠ける
-- 壊れ方は、階級数と全国での差の大きさ（総数の0.1%以内）で落とす。
--
-- 2つの表は同じ統計を年齢の絞り方だけ変えて別々に取得している。地域の階層や性別・国籍の
-- 恒等式は municipality_migration 側の migration_identities_are_consistent が見ているので、
-- ここでは総数との突き合わせで「年齢の区分が欠けた・重なった」「分類軸を取り違えた」
-- 壊れ方を落とす。
--
-- 突き合わせは総数の側から外側結合する。年齢の表から地域や年が丸ごと消えると、内部結合
-- では比較の対象そのものが生まれず、0行 = 合格を返して素通りする。
-- 原典の欠測値（矢祭町の転出者数・転入超過数）は両方の表で NULL なので、
-- IS DISTINCT FROM で NULL 同士は一致として扱う。

{% set age_codes = [
    '201', '202', '203', '204', '205', '206', '207', '208', '209', '210',
    '211', '212', '213', '214', '215', '216', '217', '218', '402'
] %}

WITH age_sum AS (
    SELECT area, year, sex_code, nationality_code,
        COUNT(*) AS n,
        SUM(inflow) AS inflow,
        SUM(outflow) AS outflow,
        SUM(net_inflow) AS net_inflow,
        COUNT(*) FILTER (WHERE outflow IS NULL) AS outflow_nulls,
        COUNT(*) FILTER (WHERE net_inflow IS NULL) AS net_inflow_nulls
    FROM {{ ref('municipality_migration_age') }}
    GROUP BY area, year, sex_code, nationality_code
),

compared AS (
    SELECT t.area, t.year, t.sex_code, t.nationality_code,
        t.inflow AS in_total, t.outflow AS out_total, t.net_inflow AS net_total,
        a.n, a.inflow AS in_sum,
        -- 欠測が一部の階級だけに入ると SUM は残りの階級の和を返すので、総数の NULL と
        -- 突き合わせられるよう、1つでも欠けていれば NULL に寄せる。
        CASE WHEN a.outflow_nulls = 0 THEN a.outflow END AS out_sum,
        CASE WHEN a.net_inflow_nulls = 0 THEN a.net_inflow END AS net_sum
    FROM {{ ref('municipality_migration') }} t
    LEFT JOIN age_sum a
        ON a.area = t.area AND a.year = t.year
        AND a.sex_code = t.sex_code AND a.nationality_code = t.nationality_code
    WHERE t.year >= 2014
),

age_by_year AS (
    SELECT year, LIST_SORT(ARRAY_AGG(DISTINCT age_code)) AS codes
    FROM {{ ref('municipality_migration_age') }}
    GROUP BY year
)

SELECT '行が無い、または収録が2014年から始まっていない' AS violation,
    COALESCE(CAST(min_year AS VARCHAR), 'empty') AS detail
FROM (
    SELECT COUNT(*) AS rows, MIN(year) AS min_year
    FROM {{ ref('municipality_migration_age') }}
)
WHERE rows = 0 OR min_year <> 2014

UNION ALL

SELECT '年齢階級の顔ぶれが違う',
    CAST(year AS VARCHAR) || ' ' || ARRAY_TO_STRING(codes, ',')
FROM age_by_year
WHERE codes <> LIST_SORT({{ age_codes }}::VARCHAR[])

UNION ALL

SELECT '総数の表にあって年齢の表に無い、または階級が19に揃っていない',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code || ' ' || nationality_code
        || ' 階級' || COALESCE(CAST(n AS VARCHAR), '0')
FROM compared
WHERE n IS DISTINCT FROM 19

UNION ALL

SELECT '年齢の表にあって総数の表に無い',
    a.area || ' ' || CAST(a.year AS VARCHAR) || ' ' || a.sex_code || ' ' || a.nationality_code
FROM age_sum a
LEFT JOIN {{ ref('municipality_migration') }} t
    ON t.area = a.area AND t.year = a.year
    AND t.sex_code = a.sex_code AND t.nationality_code = a.nationality_code
WHERE t.area IS NULL

UNION ALL

SELECT '地域×年×性別×国籍×年齢が一意でない',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code || ' '
        || nationality_code || ' ' || age_code
FROM {{ ref('municipality_migration_age') }}
GROUP BY area, year, sex_code, nationality_code, age_code
HAVING COUNT(*) > 1

UNION ALL

SELECT '転入超過数 <> 転入者数 - 転出者数',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code || ' '
        || nationality_code || ' ' || age_code
FROM {{ ref('municipality_migration_age') }}
WHERE inflow IS NOT NULL AND outflow IS NOT NULL AND net_inflow IS NOT NULL
    AND net_inflow <> inflow - outflow

UNION ALL

SELECT '年齢階級の和 > 総数',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code || ' ' || nationality_code
FROM compared
WHERE n = 19 AND (in_sum > in_total OR out_sum > out_total)

UNION ALL

SELECT '総数との差が 転入 - 転出 = 転入超過 になっていない',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code || ' ' || nationality_code
FROM compared
WHERE n = 19
    AND (in_total - in_sum) - (out_total - out_sum) IS DISTINCT FROM net_total - net_sum
    AND out_total IS NOT NULL AND net_total IS NOT NULL

UNION ALL

SELECT '欠測値が総数と年齢の表で揃っていない',
    area || ' ' || CAST(year AS VARCHAR) || ' ' || sex_code || ' ' || nationality_code
FROM compared
WHERE n = 19
    AND ((out_total IS NULL) <> (out_sum IS NULL) OR (net_total IS NULL) <> (net_sum IS NULL))

UNION ALL

SELECT '全国で年齢階級の和が総数から0.1%を超えて離れている',
    CAST(year AS VARCHAR) || ' ' || sex_code || ' ' || nationality_code
        || ' 転入' || CAST(in_total - in_sum AS VARCHAR)
        || ' 転出' || CAST(out_total - out_sum AS VARCHAR)
FROM compared
WHERE area = '00000' AND n = 19
    AND (in_total - in_sum > in_total * 0.001 OR out_total - out_sum > out_total * 0.001)
