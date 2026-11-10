---
title: 児童生徒数・学校数・教員数（学校基本調査）
order: 28
---

# 学校基本調査（school）

小学校・中学校の児童生徒数・学校数・教員数を収録します。都道府県別の学年別児童生徒数（enrollment_by_grade）と、市区町村別の3表（municipality_*）があります。

## 都道府県別の学年別児童生徒数（enrollment_by_grade）

小学校の学年別児童数と中学校の学年別生徒数を、都道府県別・設置者別・男女別に収録します。

- `e_stat.school.enrollment_by_grade`: 119,808行（小学校 74,880行、中学校 44,928行）

収録は2000〜2025年で、毎年5月1日現在の在学者数です。

出典: [文部科学省 学校基本調査](https://www.e-stat.go.jp/stat-search/files?toukei=00400001)

## カラム構成

- year: 調査年（2000〜2025）
- school_type / school_type_name: 学校種（`elementary` 小学校・`junior_high` 中学校）
- founder_code / founder: 設置者（`0` 計・`1` 国立・`2` 公立・`3` 私立）
- area / area_name / prefecture_code: 地域コード（`00000` 全国・`XX000` 都道府県） / 地域名 / 都道府県コード（全国は NULL）
- grade: 学年（小学校 1〜6、中学校 1〜3。`0` は学年の計）
- sex_code / sex: 男女（`0` 男女計・`1` 男・`2` 女）。男女計は学年の計の行にだけある
- students: 児童数・生徒数（人）

## 小学1年生の増減を都道府県で並べる

```sql
SELECT area_name,
    sum(students) FILTER (WHERE year = 2000) AS y2000,
    sum(students) FILTER (WHERE year = 2025) AS y2025,
    round(100.0 * sum(students) FILTER (WHERE year = 2025) / sum(students) FILTER (WHERE year = 2000) - 100, 1) AS change_pct
FROM e_stat.school.enrollment_by_grade
WHERE school_type = 'elementary' AND founder_code = '0' AND grade = 1 AND area <> '00000'
GROUP BY area_name
ORDER BY change_pct
```

全国の小学1年生は2000年の1,192,258人から2025年の897,428人に減りました。秋田県は52.7%減、青森県は49.5%減で、増えたのは東京都（4.5%増）だけです。

## 私立に通う中学生の割合

```sql
SELECT area_name,
    round(100.0 * sum(students) FILTER (WHERE founder_code = '3')
        / sum(students) FILTER (WHERE founder_code = '0'), 1) AS private_pct
FROM e_stat.school.enrollment_by_grade
WHERE school_type = 'junior_high' AND year = 2025 AND grade = 0 AND sex_code = '0' AND area <> '00000'
GROUP BY area_name
ORDER BY private_pct DESC
```

2025年は東京都が26.7%で最も高く、高知県18.6%、京都府14.4%と続きます。

## 計と内訳が同じ列に並ぶ

設置者の計、全国、学年の計（grade = 0）、男女計（sex_code = '0'）が内訳と同じ列にあるので、絞らずに足すと二重に数えます。学年別の行は男と女だけで、男女計は学年の計の行にだけあります。

## この表に入らない在学者

義務教育学校、中等教育学校の前期課程、特別支援学校の小学部・中学部の在学者は入りません。

## 原典の値を直したセル

原典で「-」のセルは 0 です。2003年の小学校 公立 福岡県 男 の計は原典で 14656 と1桁欠けているので、男女・学年・都道府県・設置者の合計がそろう 146656 に直しています。


## 市区町村別の学校数・児童生徒数・教員数（municipality_*）

- `e_stat.school.municipality_schools`: 学校数。設置者（計・国立・公立・私立）× 公立の内訳（市(区)立・町立など）× 本校・分校。417,831行
- `e_stat.school.municipality_students`: 児童生徒数。学年 × 男女（国立・公立・私立の計）。320,661行
- `e_stat.school.municipality_teachers`: 本務教員数。職名 × 男女（国立・公立・私立の計）。757,926行

収録は2021〜2025年で、毎年5月1日現在です。

出典: [文部科学省 学校基本調査（市町村別集計）](https://www.e-stat.go.jp/stat-search/files?toukei=00400001)

### 地域の列

- area: 地域コード（5桁）。都道府県の計は `XX000`
- area_level: `prefecture`（都道府県の計）・`municipality`（市区町村）・`ward`（政令指定都市の区）・`outside`（原典の「東京都外」「大阪市外」の行）
- city_code: 市区町村コード。政令指定都市の区は市のコード（札幌市中央区なら `01100`）、ほかの市区町村は area と同じ

政令指定都市は区の行だけで、市の行はありません。市の値は city_code で区を足して出します。都道府県の計は、市区町村・区・outside の行を足した値に一致します。全国の行は無いので、都道府県の計を足して出します。

浜松市は2024年1月に区を再編したので、2023年までの旧区（22131〜22137）は現行の code.municipality にありません。city_code は浜松市（22130）です。

### 小学校の児童数が増えた市区町村

```sql
SELECT city_code,
    sum(students) FILTER (WHERE year = 2021) AS y2021,
    sum(students) FILTER (WHERE year = 2025) AS y2025,
    round(100.0 * sum(students) FILTER (WHERE year = 2025) / sum(students) FILTER (WHERE year = 2021) - 100, 1) AS change_pct
FROM e_stat.school.municipality_students
WHERE school_type = 'elementary' AND grade = 0 AND sex = '計' AND city_code IS NOT NULL
GROUP BY city_code
HAVING sum(students) FILTER (WHERE year = 2021) >= 10000
ORDER BY change_pct DESC
```

児童数が1万人以上の市区町村では、2021年から2025年に流山市（12220）が14.8%、つくば市（08220）が14.5%、文京区（13105）が9.0%増えました。名前は `e_stat.code.municipality` と city_code で結合して付けます。

### 計と内訳

学校数の設置者（founder）は計・国立・公立・私立、公立の内訳（founder_detail）は市(区)立・町立・村立・組合立（中学校は都道府県立も）、本校分校（campus）は計・本校・分校です。教員数の職名（position）は計と、校長・副校長・教頭・主幹教諭・指導教諭・教諭・助教諭・養護教諭・養護助教諭・栄養教諭・講師の12の内訳、それに市町村費負担の者(再掲)です。教員数は本務教員だけで、兼務者（非常勤など）は入りません。

学校数は設置者・公立の内訳・本校分校の計が、児童生徒数は学年の計（grade = 0）と男女の計（sex = '計'）が、教員数は職名の計と男女の計が、内訳と同じ列に並びます。教員数の「市町村費負担の者(再掲)」は計の内数です。小学校の学校数の表には都道府県立の列が無く、都立の小学校（立川市の1校）は公立の計にだけ入ります。

都道府県の計の児童生徒数は enrollment_by_grade の計と一致します。2025年の全国は、学校数が小学校18,607校・中学校9,827校、本務教員数が小学校424,894人・中学校247,305人です。義務教育学校・中等教育学校・特別支援学校は入りません。

この3表は毎日の更新（CI）では取らず、手元で1回だけ取り込んでいます（`local_tables.yml` の `school_municipality`）。

## 補足: 学校基本調査 学年別の児童生徒数（school スキーマ）

#### 計と内訳が同じ列に並ぶ

設置者（founder_code）の計、全国（area = '00000'）、学年の計（grade = 0）、男女計（sex_code = '0'）が
内訳と同じ列にあります。絞らずに足すと二重に数えます。男女計の行は学年の計にだけあり、
学年別の行は男と女だけです。

## 補足: school.enrollment_by_grade

調査日は毎年5月1日。
学年 grade は小学校 1〜6、中学校 1〜3 で、0 が学年の計。
設置者 founder_code は 0=計、1=国立、2=公立、3=私立。
2025年の全国の児童数は 5,812,375人（2000年 7,366,079人）、生徒数は 3,105,297人（同 4,103,717人）。
原典で「-」のセル（その都道府県にその設置者の学校が無いなど）は 0。
