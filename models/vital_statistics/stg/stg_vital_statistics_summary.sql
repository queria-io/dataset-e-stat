{# 人口動態総覧の12項目を、年 × 地域 1 行の列に開く。
   原典の「-」(計数のない場合) は 0 の意味なので 0 にする。この表に「-」以外の記号は無い
   (2026-03-17 更新分の全 246,936 セルで確認)。 #}
SELECT
    CAST(SUBSTR(r.time, 1, 4) AS INTEGER) AS year,
    a.area_code,
    a.area_name,
    a.area_kind,
    a.prefecture_code,
    {% for code, col in [
        ('100', 'births'),
        ('110', 'low_birth_weight_births'),
        ('120', 'deaths'),
        ('130', 'infant_deaths'),
        ('140', 'neonatal_deaths'),
        ('190', 'early_neonatal_deaths'),
        ('150', 'spontaneous_fetal_deaths'),
        ('160', 'induced_fetal_deaths'),
        ('180', 'late_fetal_deaths'),
        ('170', 'perinatal_deaths'),
        ('200', 'marriages'),
        ('210', 'divorces'),
    ] %}
    CAST(COALESCE(MAX(r.value) FILTER (WHERE r.cat01 = '{{ code }}'), 0) AS BIGINT) AS {{ col }},
    {% endfor %}
    COUNT(*) AS cells
FROM {{ ref('raw_vital_statistics_summary') }} AS r
INNER JOIN {{ ref('stg_vital_statistics_area') }} AS a ON a.area = r.area
GROUP BY ALL
