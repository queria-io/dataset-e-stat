{# 借家（2）の主世帯数が、内訳（21 公営・22 UR公社・23 民営・24 給与）の合計と合うこと。
   所有の関係の区分コードが変わったり、内訳を取りこぼしたりしたら落ちる。

   値は丸めてあり、丸めの単位は地域で違う。市区町村は10世帯単位、全国・都道府県・
   政令指定都市は100世帯単位 (2023年の表で、全値が100の倍数の地域が69)。
   借家と内訳4つの5つの値がそれぞれ単位の半分までずれうるので、単位の2.5倍まで許す。
   実データのずれは10世帯単位の地域で最大20、100世帯単位の地域で最大200。 #}
WITH unit AS (
    SELECT
        area,
        CASE WHEN BOOL_AND(households % 100 = 0) THEN 100 ELSE 10 END AS rounding_unit
    FROM {{ ref('municipality_income_tenure') }}
    WHERE households IS NOT NULL
    GROUP BY area
),

t AS (
    SELECT
        area,
        income_class_code,
        COUNT(*) FILTER (WHERE tenure_code = '2') AS rented_rows,
        MAX(households) FILTER (WHERE tenure_code = '2') AS rented,
        SUM(COALESCE(households, 0)) FILTER (WHERE tenure_code IN ('21', '22', '23', '24')) AS parts
    FROM {{ ref('municipality_income_tenure') }}
    GROUP BY area, income_class_code
)

SELECT t.*, COALESCE(u.rounding_unit, 10) AS rounding_unit
FROM t
LEFT JOIN unit AS u ON t.area = u.area
-- 借家の行がちょうど1つでない、または内訳の行が1つも無い (parts が NULL) ときは
-- 値によらず落とす。「-」(NULL) は 0 として比べる。
WHERE t.rented_rows <> 1
    OR t.parts IS NULL
    OR ABS(COALESCE(t.rented, 0) - t.parts) > 2.5 * COALESCE(u.rounding_unit, 10)
