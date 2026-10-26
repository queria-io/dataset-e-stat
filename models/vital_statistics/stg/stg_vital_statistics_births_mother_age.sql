{# 母の年齢（5歳階級）別の出生数を、年 × 地域 × 母の年齢 1 行にし、子の性別を列に開く。
   cat01=母の年齢 (00100 総数、00190 14歳以下 … 00310 50歳以上、00450 不詳)、
   cat02=性別 (00100 総数、00110 男、00120 女)。
   原典の「-」は 0 の意味なので 0 にする。この表に「-」以外の記号は無い
   (2026-03-17 更新分の全 641,124 セルで確認)。 #}
SELECT
    CAST(SUBSTR(r.time, 1, 4) AS INTEGER) AS year,
    a.area_code,
    a.area_name,
    a.area_kind,
    a.prefecture_code,
    r.cat01 AS mother_age_code,
    ANY_VALUE(r.cat01_metadata->>'$.name') AS mother_age_class,
    CAST(COALESCE(MAX(r.value) FILTER (WHERE r.cat02 = '00100'), 0) AS BIGINT) AS births,
    CAST(COALESCE(MAX(r.value) FILTER (WHERE r.cat02 = '00110'), 0) AS BIGINT) AS births_male,
    CAST(COALESCE(MAX(r.value) FILTER (WHERE r.cat02 = '00120'), 0) AS BIGINT) AS births_female,
    COUNT(*) AS cells
FROM {{ ref('raw_vital_statistics_births_mother_age') }} AS r
INNER JOIN {{ ref('stg_vital_statistics_area') }} AS a ON a.area = r.area
GROUP BY ALL
