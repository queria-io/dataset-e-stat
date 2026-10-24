{# 借家（2）の主世帯数が、内訳（21 公営・22 UR公社・23 民営・24 給与）の合計と合うこと。
   所有の関係の区分コードが変わったり、内訳を取りこぼしたりしたら落ちる。
   値は10世帯単位に丸めてあるので、内訳4つの丸めの分（最大 20 世帯）は許す。 #}
WITH t AS (
    SELECT
        area,
        income_class_code,
        MAX(households) FILTER (WHERE tenure_code = '2') AS rented,
        SUM(COALESCE(households, 0)) FILTER (WHERE tenure_code IN ('21', '22', '23', '24')) AS parts
    FROM {{ ref('municipality_income_tenure') }}
    GROUP BY area, income_class_code
)

SELECT *
FROM t
WHERE rented IS NOT NULL AND ABS(rented - parts) > 20
