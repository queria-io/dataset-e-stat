-- 学校基本調査の市町村別の表 (school.municipality_schools・municipality_students・
-- municipality_teachers) の整合を検証する。結果が0行ならテスト成功。
--
-- 1. 市区町村の行の合計 = 都道府県の計 (列ごと)。行や列の取り違えで合わなくなる
-- 2. 内訳の合計 = 計
--    - 学校数: 国立 + 公立 + 私立 = 計、本校 + 分校 = 計、公立の内訳の合計 = 公立の計。
--      小学校の表には都道府県立の列が無く、都立の小学校 (立川市の1校) が公立の計にだけ
--      入るので、小学校は内訳の合計 <= 公立の計で見る
--    - 児童生徒数: 学年の合計 = 学年の計、男 + 女 = 計
--    - 本務教員数: 男 + 女 = 計、職名の内訳 (市町村費負担の者(再掲) を除く) の合計 = 計
-- 3. 都道府県の計の児童生徒数が school.enrollment_by_grade (都道府県別、CI で取る別の表) と一致する
-- 4. 都道府県外の行と浜松市の旧区を除き、市区町村の行がすべて現行の code.municipality に当たる
-- 5. 2021年から最新年まで年が連続し、各年に2つの学校種と47都道府県がそろう

WITH s AS (SELECT * FROM {{ ref('municipality_schools') }}),
st AS (SELECT * FROM {{ ref('municipality_students') }}),
t AS (SELECT * FROM {{ ref('municipality_teachers') }}),

cells AS (
    SELECT 'schools' AS tbl, year, school_type, area_level, prefecture_code, city_code, area,
        founder || '/' || founder_detail || '/' || campus AS item, schools AS value
    FROM s
    UNION ALL
    SELECT 'students', year, school_type, area_level, prefecture_code, city_code, area,
        grade::VARCHAR || '/' || sex, students
    FROM st
    UNION ALL
    SELECT 'teachers', year, school_type, area_level, prefecture_code, city_code, area,
        position || '/' || sex, teachers
    FROM t
),

prefecture_totals AS (
    SELECT tbl, year, school_type, prefecture_code, item,
        sum(value) FILTER (WHERE area_level <> 'prefecture') AS municipalities,
        max(value) FILTER (WHERE area_level = 'prefecture') AS prefecture
    FROM cells
    GROUP BY ALL
),

school_parts AS (
    SELECT year, school_type, prefecture_code, area, area_name,
        max(schools) FILTER (WHERE founder = '国立')
            + max(schools) FILTER (WHERE founder = '公立' AND founder_detail = '計' AND campus = '計')
            + max(schools) FILTER (WHERE founder = '私立') AS founders,
        max(schools) FILTER (WHERE founder = '計' AND campus = '計') AS total,
        max(schools) FILTER (WHERE founder = '計' AND campus = '本校')
            + max(schools) FILTER (WHERE founder = '計' AND campus = '分校') AS campuses,
        sum(schools) FILTER (WHERE founder = '公立' AND founder_detail <> '計' AND campus = '計') AS public_parts,
        max(schools) FILTER (WHERE founder = '公立' AND founder_detail = '計' AND campus = '計') AS public_total
    FROM s
    GROUP BY ALL
),

student_parts AS (
    SELECT year, school_type, prefecture_code, area, area_name,
        sum(students) FILTER (WHERE grade > 0 AND sex = '計') AS grades,
        max(students) FILTER (WHERE grade = 0 AND sex = '計') AS total,
        sum(students) FILTER (WHERE grade = 0 AND sex <> '計') AS sexes
    FROM st
    GROUP BY ALL
),

teacher_parts AS (
    SELECT year, school_type, prefecture_code, area, area_name, position,
        sum(teachers) FILTER (WHERE sex <> '計') AS sexes,
        max(teachers) FILTER (WHERE sex = '計') AS total
    FROM t
    GROUP BY ALL
),

position_parts AS (
    SELECT year, school_type, prefecture_code, area, area_name, sex,
        sum(teachers) FILTER (WHERE position NOT IN ('計', '市町村費負担の者(再掲)')) AS positions,
        max(teachers) FILTER (WHERE position = '計') AS total
    FROM t
    GROUP BY ALL
),

prefecture_enrollment AS (
    SELECT year, school_type, prefecture_code, students
    FROM {{ ref('enrollment_by_grade') }}
    WHERE founder_code = '0' AND grade = 0 AND sex_code = '0' AND prefecture_code IS NOT NULL
),

coverage AS (
    SELECT year, count(DISTINCT school_type) AS school_types, count(DISTINCT prefecture_code) AS prefectures
    FROM cells
    GROUP BY ALL
),

years AS (
    SELECT min(year) AS first_year, max(year) AS last_year, count(*) AS n FROM coverage
)

SELECT 'municipalities do not sum to prefecture' AS problem, tbl || ' ' || year || ' ' || school_type AS scope,
    prefecture_code || ' ' || item AS detail
FROM prefecture_totals
WHERE prefecture IS NULL OR municipalities <> prefecture

UNION ALL
SELECT 'school founders/campuses/public parts do not sum', year || ' ' || school_type, prefecture_code || ' ' || area_name
FROM school_parts
WHERE founders <> total OR campuses <> total
    OR (school_type = 'junior_high' AND public_parts <> public_total)
    OR (school_type = 'elementary' AND public_parts > public_total)

UNION ALL
SELECT 'student grades/sexes do not sum', year || ' ' || school_type, prefecture_code || ' ' || area_name
FROM student_parts
WHERE grades <> total OR sexes <> total

UNION ALL
SELECT 'teacher sexes do not sum', year || ' ' || school_type, prefecture_code || ' ' || area_name || ' ' || position
FROM teacher_parts
WHERE sexes <> total

UNION ALL
SELECT 'teacher positions do not sum', year || ' ' || school_type, prefecture_code || ' ' || area_name || ' ' || sex
FROM position_parts
WHERE positions <> total

UNION ALL
SELECT 'prefecture students differ from enrollment_by_grade', st.year || ' ' || st.school_type, st.prefecture_code
FROM st
LEFT JOIN prefecture_enrollment e USING (year, school_type, prefecture_code)
WHERE st.area_level = 'prefecture' AND st.grade = 0 AND st.sex = '計'
    AND e.students IS DISTINCT FROM st.students

UNION ALL
SELECT 'municipality not in code.municipality', NULL, a.prefecture_name || ' ' || a.municipality_code || ' ' || a.municipality_name
FROM {{ ref('stg_school_municipality_area') }} a
WHERE a.prefecture_code IS NULL
    OR (a.area_level IN ('municipality', 'ward') AND a.city_code IS NULL)

UNION ALL
SELECT 'incomplete year', year::VARCHAR, school_types || ' school types, ' || prefectures || ' prefectures'
FROM coverage
WHERE school_types <> 2 OR prefectures <> 47

UNION ALL
SELECT 'year gap', last_year::VARCHAR, n || ' years from ' || first_year
FROM years
WHERE first_year <> 2021 OR n <> last_year - 2021 + 1
