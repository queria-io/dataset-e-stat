---
title: 学年別の児童生徒数（学校基本調査）
order: 28
---

# 学校基本調査（enrollment_by_grade）

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
