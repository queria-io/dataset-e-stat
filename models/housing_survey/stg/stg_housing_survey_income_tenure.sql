{# 主世帯数 (tab=13-2023) だけを取り、地域の粒度と年収階級の金額の幅を付ける。

   地域のメタ情報の level は、この表では 1=全国・都道府県、2=市町村 (政令指定都市は市全体、
   特別区を含む)、3=政令指定都市の区。小地域集計や社会・人口統計体系とは level の振り方が違い、
   経済センサスの産業横断的集計と同じなので e_stat_economic_census_area_level で分ける。
   市町村の行は全市と一部の町村だけで、都道府県の全域は覆わない。

   年収階級のコードは 04 が欠番。「不詳」の区分は無く、10区分の合計は総数 (00) より小さい。
   原典の「-」(該当なし、または数字が得られない) は value が NULL で入る。 #}
WITH s AS (
    SELECT
        area,
        area_metadata->>'$.name' AS area_name,
        area_metadata,
        area_metadata->>'$.parent_code' AS parent_area,
        cat01 AS tenure_code,
        cat01_metadata->>'$.name' AS tenure,
        cat02 AS income_class_code,
        cat02_metadata->>'$.name' AS income_class,
        TRY_CAST(value AS DOUBLE) AS households
    FROM {{ ref('raw_housing_survey_income_tenure') }}
    WHERE tab = '13-2023'
),

bounds AS (
    -- 年収階級の幅 (万円)。上限は含まない
    SELECT * FROM (VALUES
        ('01', 0, 100), ('02', 100, 150), ('03', 150, 200), ('05', 200, 300),
        ('06', 300, 400), ('07', 400, 500), ('08', 500, 700), ('09', 700, 1000),
        ('10', 1000, 1500), ('11', 1500, NULL)
    ) AS t(income_class_code, income_lower, income_upper)
)

SELECT
    s.area,
    s.area_name,
    {{ e_stat_economic_census_area_level('s.area', 's.area_metadata') }} AS area_level,
    s.parent_area,
    s.tenure_code,
    s.tenure,
    s.income_class_code,
    s.income_class,
    b.income_lower,
    b.income_upper,
    s.households
FROM s
LEFT JOIN bounds AS b ON s.income_class_code = b.income_class_code
