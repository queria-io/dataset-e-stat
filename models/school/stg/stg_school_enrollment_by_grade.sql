-- 都道府県名を標準地域コードの一覧から当て、コードに名称を付ける。
--
-- 原典の行見出しは「青森」「青森県」と年によって揺れる略称で、コードはパイプラインが
-- 名前から振っている。名前の当て違いが無いことは tests/school_is_consistent.sql で
-- 略称と正式名を突き合わせて確かめる。
--
-- 2003年の小学校 公立 福岡県 男 の計は、原典の統計表ファイルで 146656 が 14656 と
-- 1桁欠けている。男+女=計（286870 − 140214）、学年の合計、47都道府県の合計=全国、
-- 国立+公立+私立=計 の4つがどれも 146656 を指すので、ここで直す。原典が直されて
-- 14656 でなくなったら、この行は何もしない。
WITH prefecture AS (
    SELECT pref_code, pref_name
    FROM {{ ref('stg_municipality') }}
    WHERE is_prefecture
)

SELECT
    s.survey_year AS year,
    s.school_type,
    CASE s.school_type
        WHEN 'elementary' THEN '小学校'
        WHEN 'junior_high' THEN '中学校'
    END AS school_type_name,
    s.founder_code,
    CASE s.founder_code
        WHEN '0' THEN '計'
        WHEN '1' THEN '国立'
        WHEN '2' THEN '公立'
        WHEN '3' THEN '私立'
    END AS founder,
    s.area,
    COALESCE(p.pref_name, s.area_label) AS area_name,
    s.area_label,
    s.prefecture_code,
    s.grade,
    s.sex_code,
    CASE s.sex_code
        WHEN '0' THEN '計'
        WHEN '1' THEN '男'
        WHEN '2' THEN '女'
    END AS sex,
    CASE
        WHEN s.survey_year = 2003
            AND s.school_type = 'elementary'
            AND s.founder_code = '2'
            AND s.area = '40000'
            AND s.grade = 0
            AND s.sex_code = '1'
            AND s.students = 14656
            THEN 146656
        ELSE s.students
    END AS students
FROM {{ ref('raw_school_enrollment_by_grade') }} s
LEFT JOIN prefecture p ON p.pref_code = s.prefecture_code
