{# 業種の段を足す。原典の列の並び（business_order）で決める。
   - 0 商業計、1 卸売業計、18 小売業計
   - 11〜14 は 10 機械器具卸売業の内訳
   - 28〜30 は小売業の一部をまとめた参考の計 #}
SELECT
    time,
    year,
    month,
    business_order,
    business,
    business_en,
    CASE
        WHEN business_order = 0 THEN 'total'
        WHEN business_order IN (1, 18) THEN 'sector'
        WHEN business_order BETWEEN 11 AND 14 THEN 'sub_business'
        WHEN business_order >= 28 THEN 'reference'
        ELSE 'business'
    END AS business_level,
    CASE
        WHEN business_order BETWEEN 2 AND 17 THEN '卸売業'
        WHEN business_order BETWEEN 19 AND 30 THEN '小売業'
    END AS sector,
    sales_billion_yen,
    yoy_index
FROM {{ ref('raw_commerce_sales_by_business') }}
