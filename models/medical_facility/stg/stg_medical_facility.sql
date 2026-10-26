{# 地域の名称からコードと粒度を切り出し、項目の名称を列名にそろえる。

   地域は「01　　北海道」(2桁: 都道府県)、「0101　南渡島」(4桁: 二次医療圏)、
   「01202 函館市」(5桁: 市区町村) が 1 つの軸に並ぶ。区切りの空白は年で全角・半角・
   無しと揺れるので、先頭の数字列と残りに分ける。二次医療圏の行のすぐ後にその圏の
   市区町村が続く並びなので、市区町村の二次医療圏は並び (area_order) の上で直前の
   二次医療圏の行から取る。メタ情報に親コードは入っておらず、コードの順は並びと
   違うことがある (2010 年は 6 市町村が別の圏に当たる)。

   項目の名称は年で「病院施設数」「施設数総数」、「(再掲)」「（再掲）」と揺れるので、
   括弧を半角にそろえ、先頭の「病院」を落としてから当てる。「地域医療支援病院(再掲)」は
   施設数と病床数の 2 回現れ、名称では見分けられない。病床数の総数より後ろに並ぶ方を
   病床数とする。

   値は原典の「-」(計数のない場合) が取得時に NULL になっている。この表の記号は「-」
   だけなので (実測: 2008〜2024 年の全表)、0 に倒す。 #}
WITH parsed AS (
    SELECT
        survey_year,
        table_kind,
        area_order,
        regexp_extract(area_label, '^([0-9]+)', 1) AS code,
        trim(regexp_replace(area_label, '^[0-9]+[\s　]*', ''), ' 　') AS name,
        CAST(item_code AS INTEGER) AS item_seq,
        regexp_replace(replace(replace(item_name, '（', '('), '）', ')'), '^病院', '') AS item,
        value
    FROM {{ ref('raw_medical_facility') }}
),

measured AS (
    SELECT
        *,
        CASE
            WHEN item IN ('施設数総数', '施設数') THEN 'hospitals'
            WHEN item = '施設数(精神科病院)' THEN 'psychiatric_hospitals'
            WHEN item = '施設数(結核療養所)' THEN 'tuberculosis_sanatoriums'
            WHEN item = '施設数(一般病院総数)' THEN 'general_hospitals'
            WHEN item = '施設数(一般病院総数(療養病床を有する病院(再掲)))'
                THEN 'general_hospitals_with_long_term_care_beds'
            WHEN item = '地域医療支援病院(再掲)' THEN CASE
                WHEN item_seq > MIN(item_seq) FILTER (WHERE item IN ('病床数総数', '病床数'))
                    OVER (PARTITION BY survey_year, table_kind)
                THEN 'regional_support_hospital_beds'
                ELSE 'regional_support_hospitals'
            END
            WHEN item = '救急告示病院(再掲)' THEN 'emergency_hospitals'
            WHEN item IN ('病床数総数', '病床数') THEN 'hospital_beds'
            WHEN item = '病床数(精神病床)' THEN 'psychiatric_beds'
            WHEN item = '病床数(感染症病床)' THEN 'infectious_beds'
            WHEN item = '病床数(結核病床)' THEN 'tuberculosis_beds'
            WHEN item = '病床数(療養病床)' THEN 'long_term_care_beds'
            WHEN item = '病床数(一般病床)' THEN 'general_beds'
            WHEN item = '一般診療所数総数' THEN 'general_clinics'
            WHEN item = '一般診療所数(有床)' THEN 'general_clinics_with_beds'
            WHEN item LIKE '一般診療所数((再掲)療養病床を有する%診療所)'
                THEN 'general_clinics_with_long_term_care_beds'
            WHEN item = '一般診療所数(無床)' THEN 'general_clinics_without_beds'
            WHEN item = '一般診療所病床数' THEN 'general_clinic_beds'
            WHEN item = '一般診療所((再掲)療養病床)' THEN 'general_clinic_long_term_care_beds'
            WHEN item = '歯科診療所数総数' THEN 'dental_clinics'
            WHEN item = '歯科診療所数(有床)' THEN 'dental_clinics_with_beds'
            WHEN item = '歯科診療所数(無床)' THEN 'dental_clinics_without_beds'
        END AS measure
    FROM parsed
),

areas AS (
    SELECT DISTINCT survey_year, table_kind, area_order, code, name
    FROM parsed
),

-- 市区町村の二次医療圏は、並びの上で直前にある二次医療圏の行
placed AS (
    SELECT
        *,
        CASE length(code)
            WHEN 2 THEN 'prefecture'
            WHEN 4 THEN 'medical_area'
            WHEN 5 THEN 'municipality'
        END AS area_level,
        last_value(CASE WHEN length(code) = 4 THEN code END IGNORE NULLS) OVER (
            PARTITION BY survey_year, table_kind ORDER BY area_order
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS medical_area_code,
        last_value(CASE WHEN length(code) = 4 THEN name END IGNORE NULLS) OVER (
            PARTITION BY survey_year, table_kind ORDER BY area_order
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS medical_area_name
    FROM areas
)

SELECT
    m.survey_year,
    p.area_level,
    CASE p.area_level
        WHEN 'prefecture' THEN p.code || '000'
        WHEN 'municipality' THEN p.code
    END AS area_code,
    p.name AS area_name,
    left(p.code, 2) AS prefecture_code,
    CASE WHEN p.area_level <> 'prefecture' THEN p.medical_area_code END AS medical_area_code,
    CASE WHEN p.area_level <> 'prefecture' THEN p.medical_area_name END AS medical_area_name,
    m.table_kind,
    m.item,
    m.measure,
    COALESCE(m.value, 0) AS value
FROM measured m
JOIN placed p USING (survey_year, table_kind, area_order)
