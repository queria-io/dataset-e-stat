-- medical_facility の municipality_facility が、原典の集計構造どおりに読めていることを
-- 検証する。結果が0行ならテスト成功。
--
-- 原典は地域の軸に都道府県・二次医療圏・市区町村が1列に並び、名称の先頭のコードの桁で
-- 粒度を、並びで二次医療圏の所属を読んでいる。項目の名称も年で揺れる。読み違えると
-- 行数も年もそろったまま値の意味だけが入れ替わるので、足し算で押さえる。
--
-- 1) 市区町村の和が都道府県に一致する。全23項目で1のずれも無い（実測）。
-- 2) 市区町村の和が二次医療圏に一致する。所属は並びから読んでいるので、並びが崩れると
--    ここが落ちる（コードの順で読むと2010年の6市町村が別の圏に当たる）。
-- 3) 内訳が総数に足し上がる。病院 = 精神科病院 + 結核療養所 + 一般病院、病床 = 5種の
--    病床の和、一般診療所・歯科診療所 = 有床 + 無床。再掲は総数を超えない。
--    項目の名称の当て違いはここで拾う。
-- 4) 都道府県が毎年47そろい、年が欠けない（2013年は原典の不備で取り込まないので除く）。
--    市区町村の行は必ず同じ都道府県の二次医療圏に属する。
-- 5) 1地域1行。病院の表と診療所の表で地域の名称が食い違うと行が割れる。
-- 6) 総数が0に倒れていない。値の読み込みが崩れると全部0（原典の「-」を0にしている）に
--    なって足し算を素通りする。全国の病院数は8,000を下回ったことが無い（実測の最小は
--    2024年の8,060）。
-- 7) 原典の項目がどれも列に当たっている。名称が変わって当たらなくなった項目は、列が
--    NULL になるだけで 1)〜3) を素通りする（NULL どうしは一致し、NULL との比較は落ちない）。

-- 元表が揃っていないカタログ (手元で取り込む前) では検査しない。0 行の表を検査して落とすと
-- 他のテーブルの更新まで止まるため。
{% if medical_facility_sources_loaded() %}
{% set measures = [
    'hospitals', 'psychiatric_hospitals', 'tuberculosis_sanatoriums', 'general_hospitals',
    'general_hospitals_with_long_term_care_beds', 'regional_support_hospitals',
    'emergency_hospitals', 'hospital_beds', 'psychiatric_beds', 'infectious_beds',
    'tuberculosis_beds', 'long_term_care_beds', 'general_beds', 'regional_support_hospital_beds',
    'general_clinics', 'general_clinics_with_beds', 'general_clinics_with_long_term_care_beds',
    'general_clinics_without_beds', 'general_clinic_beds', 'general_clinic_long_term_care_beds',
    'dental_clinics', 'dental_clinics_with_beds', 'dental_clinics_without_beds'
] %}
{% set first_year = 2008 %}
{% set skipped_years = [2013] %}

WITH f AS (
    SELECT * FROM {{ ref('municipality_facility') }}
),

municipality_sum AS (
    SELECT
        survey_year,
        prefecture_code,
        medical_area_code,
        {%- for m in measures %}
        SUM({{ m }}) AS {{ m }}{{ ',' if not loop.last }}
        {%- endfor %}
    FROM f
    WHERE area_level = 'municipality'
    GROUP BY GROUPING SETS ((survey_year, prefecture_code), (survey_year, medical_area_code))
),

-- 1) 2) 市区町村の和と都道府県・二次医療圏
rollup_failures AS (
    SELECT
        'rollup_' || f.area_level AS check_name,
        f.survey_year || ' ' || f.area_name AS detail
    FROM f
    LEFT JOIN municipality_sum s
        ON s.survey_year = f.survey_year
        AND CASE f.area_level
            WHEN 'prefecture' THEN s.medical_area_code IS NULL
                AND s.prefecture_code = f.prefecture_code
            ELSE s.prefecture_code IS NULL AND s.medical_area_code = f.medical_area_code
        END
    WHERE f.area_level IN ('prefecture', 'medical_area')
        AND (
            s.survey_year IS NULL
            {%- for m in measures %}
            OR f.{{ m }} IS DISTINCT FROM s.{{ m }}
            {%- endfor %}
        )
),

-- 3) 内訳と総数
partition_failures AS (
    SELECT
        'partition' AS check_name,
        survey_year || ' ' || area_name AS detail
    FROM f
    WHERE hospitals <> psychiatric_hospitals + COALESCE(tuberculosis_sanatoriums, 0)
            + general_hospitals
        OR hospital_beds <> psychiatric_beds + infectious_beds + tuberculosis_beds
            + long_term_care_beds + general_beds
        OR general_clinics <> general_clinics_with_beds + general_clinics_without_beds
        OR dental_clinics <> dental_clinics_with_beds + dental_clinics_without_beds
        OR general_hospitals_with_long_term_care_beds > general_hospitals
        OR regional_support_hospitals > hospitals
        OR emergency_hospitals > hospitals
        OR regional_support_hospital_beds > hospital_beds
        OR general_clinics_with_long_term_care_beds > general_clinics_with_beds
        OR general_clinic_long_term_care_beds > general_clinic_beds
),

-- 4) 都道府県・年・所属
prefecture_failures AS (
    SELECT
        'prefecture_count' AS check_name,
        survey_year || ' ' || COUNT(*) || ' 都道府県' AS detail
    FROM f
    WHERE area_level = 'prefecture'
    GROUP BY survey_year
    HAVING COUNT(*) <> 47
),

year_failures AS (
    SELECT 'survey_year_gap' AS check_name, CAST(year AS VARCHAR) AS detail
    FROM (
        SELECT UNNEST(RANGE(
            {{ first_year }}, COALESCE((SELECT MAX(survey_year) FROM f), 0) + 1
        )) AS year
    )
    WHERE year NOT IN ({{ skipped_years | join(', ') }})
        AND year NOT IN (SELECT DISTINCT survey_year FROM f)
),

membership_failures AS (
    SELECT
        'medical_area_missing' AS check_name,
        survey_year || ' ' || area_code || ' ' || area_name AS detail
    FROM f
    WHERE area_level = 'municipality'
        AND (medical_area_code IS NULL OR left(medical_area_code, 2) <> prefecture_code)
),

-- 5) 1地域1行
key_failures AS (
    SELECT
        'duplicate_area' AS check_name,
        survey_year || ' ' || area_level || ' ' || COALESCE(area_code, medical_area_code) AS detail
    FROM f
    GROUP BY survey_year, area_level, COALESCE(area_code, medical_area_code)
    HAVING COUNT(*) > 1
),

-- 6) 総数が0に倒れていない
value_failures AS (
    SELECT
        'national_total_too_small' AS check_name,
        survey_year || ' 病院 ' || SUM(hospitals) || ' 一般診療所 ' || SUM(general_clinics)
            AS detail
    FROM f
    WHERE area_level = 'prefecture'
    GROUP BY survey_year
    HAVING SUM(hospitals) < 8000 OR SUM(general_clinics) < 90000
),

empty_failures AS (
    SELECT 'table_is_empty' AS check_name, '0 行' AS detail
    WHERE (SELECT COUNT(*) FROM f) = 0
),

-- 7) 項目の当て漏れ
unmapped_failures AS (
    SELECT DISTINCT
        'unmapped_item' AS check_name,
        survey_year || ' ' || table_kind || ' ' || item AS detail
    FROM {{ ref('stg_medical_facility') }}
    WHERE measure IS NULL
)

SELECT * FROM rollup_failures
UNION ALL SELECT * FROM partition_failures
UNION ALL SELECT * FROM prefecture_failures
UNION ALL SELECT * FROM year_failures
UNION ALL SELECT * FROM membership_failures
UNION ALL SELECT * FROM key_failures
UNION ALL SELECT * FROM value_failures
UNION ALL SELECT * FROM empty_failures
UNION ALL SELECT * FROM unmapped_failures
{% else %}
SELECT NULL AS check_name, NULL AS detail WHERE FALSE
{% endif %}
