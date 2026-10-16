{# 表章項目（tab）の9指標を列に開いて、(年, 業種, 給与階級, 性別) で1行にする。
   指標ごとに単位が違う（歳・年・人・百万円・千円）ので、縦持ちのままだと
   unit を見ずに集計すると桁を取り違える。

   給与階級は「100万円以下」「200万円以下」…の上限だけの名前で、実際は
   「前の階級の上限を超え、この上限以下」の区間。区間の両端を万円で持たせる。

   原典の「-」（該当する計数のないとき）は value が NULL で入る。 #}
WITH s AS (
    SELECT
        cat01,
        cat01_metadata->>'$.name' AS industry,
        cat02,
        cat02_metadata->>'$.name' AS salary_class,
        cat03,
        cat03_metadata->>'$.name' AS sex,
        time,
        MAX(value) FILTER (WHERE tab = '0100') AS avg_age,
        MAX(value) FILTER (WHERE tab = '0110') AS avg_tenure_years,
        MAX(value) FILTER (WHERE tab = '0120') AS earners,
        MAX(value) FILTER (WHERE tab = '0130') AS wages_total,
        MAX(value) FILTER (WHERE tab = '0140') AS wages_avg,
        MAX(value) FILTER (WHERE tab = '0150') AS bonus_total,
        MAX(value) FILTER (WHERE tab = '0160') AS bonus_avg,
        MAX(value) FILTER (WHERE tab = '0170') AS pay_total,
        MAX(value) FILTER (WHERE tab = '0180') AS pay_avg
    FROM {{ ref('raw_private_salary_industry') }}
    GROUP BY cat01, industry, cat02, salary_class, cat03, sex, time
),

bounds AS (
    SELECT * FROM (VALUES
        ('1', 0, 100), ('2', 100, 200), ('3', 200, 300), ('4', 300, 400),
        ('5', 400, 500), ('6', 500, 600), ('7', 600, 700), ('8', 700, 800),
        ('9', 800, 900), ('10', 900, 1000), ('11', 1000, 1500),
        ('12', 1500, 2000), ('13', 2000, 2500), ('14', 2500, NULL)
    ) AS t(salary_class_code, salary_class_lower, salary_class_upper)
)

SELECT
    TRY_CAST(substr(s.time, 1, 4) AS INTEGER) AS year,
    s.cat01 AS industry_code,
    s.industry,
    s.cat02 AS salary_class_code,
    s.salary_class,
    b.salary_class_lower,
    b.salary_class_upper,
    s.cat03 AS sex_code,
    s.sex,
    s.avg_age,
    s.avg_tenure_years,
    CAST(s.earners AS BIGINT) AS earners,
    CAST(s.wages_total AS BIGINT) AS wages_total,
    CAST(s.wages_avg AS BIGINT) AS wages_avg,
    CAST(s.bonus_total AS BIGINT) AS bonus_total,
    CAST(s.bonus_avg AS BIGINT) AS bonus_avg,
    CAST(s.pay_total AS BIGINT) AS pay_total,
    CAST(s.pay_avg AS BIGINT) AS pay_avg
FROM s
LEFT JOIN bounds b ON b.salary_class_code = s.cat02
