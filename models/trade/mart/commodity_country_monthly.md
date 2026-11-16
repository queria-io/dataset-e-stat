---
$schema: https://queria.io/schemas/table/v1.json
table: trade.commodity_country_monthly
title: 品目別・国別の輸出入（月次）
description: |-
  財務省 普通貿易統計の品別国別表（全国分）を、輸出入・年・月・統計品目番号（9桁）・国ごとに縦に持つテーブルです。1988年からの数量と金額（千円）を収録しています。

  - 数量も金額も0の月は行にしていません
  - 数量の単位は品目ごとに違うので、品目をまたいで数量を足さないでください
  - 新しい年の値は確報・速報で、毎日の更新で置き換わります
keywords:
  - e-stat
  - 貿易統計
  - 財務省
  - 税関
  - 輸出
  - 輸入
  - HS コード
  - 品目
  - 国別
sources:
  - path: https://www.e-stat.go.jp/stat-search/files?toukei=00350300
fields:
  - name: flow
    title: 輸出入
    description: export=輸出、import=輸入
  - name: flow_name
    title: 輸出入名
    description: 輸出 または 輸入
  - name: year
    title: 年
    description: 暦年（西暦4桁）。1988年から
  - name: month
    title: 月
    description: 月（1〜12）
  - name: hs_code
    title: 統計品目番号
    description: 輸出入統計品目表の統計品目番号（9桁）。先頭6桁が HS コード。輸出と輸入で品目表が別なので、同じ番号でも中身が違うことがある。年によって品目の新設・統合がある。「03XXXXXXA」のように X を含む番号は、原典が個別の品目を出さずにまとめた行
  - name: hs2
    title: 類
    description: 統計品目番号の先頭2桁（類）
  - name: hs4
    title: 項
    description: 統計品目番号の先頭4桁（項）
  - name: hs6
    title: 号
    description: 統計品目番号の先頭6桁（HS の号）
  - name: country_code
    title: 国名コード
    description: 貿易統計の国名コード（3桁）。103=大韓民国、105=中華人民共和国、304=アメリカ合衆国 など
  - name: country_name
    title: 国名
    description: country_code に対応する国名。データベースの品別国別表の地域軸から取った。同じコードの名前が年で変わったものは新しい名前
  - name: unit1
    title: 第1数量の単位
    description: 第1数量（quantity1）の単位（NO=個数、SM=平方メートル、DZ=ダース など）。第1数量の無い品目は NULL（2025〜2026年の行の約7割）
  - name: unit2
    title: 第2数量の単位
    description: 第2数量（quantity2）の単位（KG=キログラム、MT=メートルトン、NO=個数、L=リットル など）。ほとんどの品目は KG
  - name: quantity1
    title: 第1数量
    description: 第1数量。単位は unit1。品目によって単位が違うので、品目をまたいで足さない
  - name: quantity2
    title: 第2数量
    description: 第2数量。単位は unit2
  - name: value_thousand_yen
    title: 金額
    description: 金額（千円）。輸出は FOB、輸入は CIF の価格
  - name: release
    title: 公表の段階
    description: その行を取ったファイルの公表の段階（確定・確々報・確報・輸入9桁速報 など）。新しい年の値は確報や速報で、後で直ることがある
  - name: source_sha256
    title: 元のファイル
    description: この行を作った CSV ファイルの sha256。source_file の sha256 と結合すると、取得した URL と日時を確認できる。過去の年の行（2024年まで）は取得の記録が無いので NULL
themes:
  - economy
---

# 普通貿易統計 品目別・国別の輸出入（月次）

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| commodity_country_monthly | 輸出入・年・月・統計品目番号（9桁）・国ごとの数量と金額（1988年〜） | flow / year / month / hs_code / hs2 / hs4 / hs6 / country_code / country_name / unit1 / unit2 / quantity1 / quantity2 / value_thousand_yen / release |
| source_file | 取得したファイルの一覧。1 行が 1 つのファイル | url / page_url / sha256 / bytes / retrieved_at |

財務省の普通貿易統計のうち、品別国別表（全国分）です。輸出と輸入それぞれについて、統計品目番号
（9桁）と国の組ごとに、月の数量と金額を持ちます。1988年から最新の公表月まで、約5,000万行あります。
数量も金額も0の月は行にしていません。

## 統計品目番号

`hs_code` は輸出入統計品目表の統計品目番号（9桁）で、先頭6桁が国際的な HS コードです。
`hs2`（類）・`hs4`（項）・`hs6`（号）で上位の分類に集計できます。輸出と輸入で品目表が別なので、
同じ番号でも中身が違うことがあります。品目は年によって新設・統合されます。
「03XXXXXXA」のように X を含む番号は、原典が個別の品目を出さずにまとめた行です。

品目名はこのテーブルにありません。税関の輸出統計品目表・輸入統計品目表で引いてください。

## 数量と金額

金額 `value_thousand_yen` の単位は千円です。輸出は FOB、輸入は CIF の価格です。
数量は第1数量・第2数量の2つがあり、単位は `unit1`・`unit2` に入っています（KG・NO=個数 など）。
品目ごとに単位が違うので、品目をまたいで数量を足さないでください。

```sql
-- 2024年 国別の輸出額の上位（兆円）
SELECT country_name, round(sum(value_thousand_yen) / 1e9, 1) AS export_trillion_yen
FROM e_stat.trade.commodity_country_monthly
WHERE flow = 'export' AND year = 2024
GROUP BY country_name
ORDER BY export_trillion_yen DESC
LIMIT 5;
```

品目で絞る問い合わせは、`hs_code` の範囲（`hs_code LIKE '8703%'` など）で絞ると読む量が少なくなります。
行は統計品目番号の順に並べて書いてあり、1つの行グループに近い番号の行がまとまっています。

## 新しい年の値

2024年までは確定値を一度取り込んだもので、2025年からは毎日の更新で e-Stat から取り直して置き換えます。新しい年の値は確報・速報で、後から直ることがあります。`release` に、その行を取った
ファイルの公表の段階（確定・確々報・確報・輸入9桁速報 など）が入っています。
