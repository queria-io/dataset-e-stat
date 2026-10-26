{# 死因（選択死因分類）別の死亡数を、年 × 地域 × 死因 1 行にし、性別を列に開く。
   cat01=性別 (00100 総数、00110 男、00120 女)、cat02=選択死因分類 (Se00 総数 … Se34 自殺)。
   原典の「-」(計数のない場合) は 0 にする。「・」(統計項目のあり得ない場合) は男の
   子宮の悪性新生物 (Se12) にだけ出るので、そこは NULL のままにする。raw ではどちらの
   記号も NULL になっていて区別できないため、出る場所で分ける
   (2026-03-17 更新分の全 2,159,838 セルで「-」423,314・「・」19,458 を確認)。 #}
SELECT
    CAST(SUBSTR(r.time, 1, 4) AS INTEGER) AS year,
    a.area_code,
    a.area_name,
    a.area_kind,
    a.prefecture_code,
    r.cat02 AS cause_code,
    ANY_VALUE(r.cat02_metadata->>'$.name') AS cause_name,
    ANY_VALUE(r.cat02_metadata->>'$.level') AS cause_meta_level,
    CAST(COALESCE(MAX(r.value) FILTER (WHERE r.cat01 = '00100'), 0) AS BIGINT) AS deaths,
    CASE WHEN ANY_VALUE(r.cat02) <> 'Se12' THEN
        CAST(COALESCE(MAX(r.value) FILTER (WHERE r.cat01 = '00110'), 0) AS BIGINT)
    END AS deaths_male,
    CAST(COALESCE(MAX(r.value) FILTER (WHERE r.cat01 = '00120'), 0) AS BIGINT) AS deaths_female,
    COUNT(*) AS cells
FROM {{ ref('raw_vital_statistics_deaths_cause') }} AS r
INNER JOIN {{ ref('stg_vital_statistics_area') }} AS a ON a.area = r.area
GROUP BY ALL
