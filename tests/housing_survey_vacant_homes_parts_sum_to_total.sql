{# 空き家の種類の内訳 (1〜4) の合計が総数 (0) と合うこと。種類の区分コードが変わったり、
   内訳を取りこぼしたりしたら落ちる。

   値は丸めてあり、丸めの単位は地域で違う (市区町村は10戸単位、全国・都道府県・政令指定都市は
   100戸単位)。総数と内訳4つの5つの値がそれぞれ単位の半分までずれうるので、単位の2.5倍まで許す。
   建て方・構造・腐朽の軸は総数 (0) の行だけで比べる。 #}
WITH unit AS (
    SELECT
        area,
        CASE WHEN BOOL_AND(vacant_homes % 100 = 0) THEN 100 ELSE 10 END AS rounding_unit
    FROM {{ ref('municipality_vacant_homes') }}
    WHERE vacant_homes IS NOT NULL
    GROUP BY area
),

t AS (
    SELECT
        area,
        COUNT(*) FILTER (WHERE vacancy_type_code = '0') AS total_rows,
        MAX(vacant_homes) FILTER (WHERE vacancy_type_code = '0') AS total,
        SUM(COALESCE(vacant_homes, 0)) FILTER (WHERE vacancy_type_code IN ('1', '2', '3', '4')) AS parts
    FROM {{ ref('municipality_vacant_homes') }}
    WHERE decay_code = '0' AND building_type_code = '0' AND structure_code = '0'
    GROUP BY area
)

SELECT t.*, COALESCE(u.rounding_unit, 10) AS rounding_unit
FROM t
LEFT JOIN unit AS u ON t.area = u.area
WHERE t.total_rows <> 1
    OR t.parts IS NULL
    OR ABS(COALESCE(t.total, 0) - t.parts) > 2.5 * COALESCE(u.rounding_unit, 10)
