---
$schema: https://queria.io/schemas/table/v1.json
table: building_starts.municipality_use
title: 市区町村別・用途別の建築着工
description: |-
  建築着工統計調査の市区町村別・用途別の着工建築物の数・床面積・工事費予定額を、2011年から年次で持つテーブルです。

  - 市区町村と政令指定都市の区の行があるので、area_level で絞らずに合計すると二重に数えます
  - 工事費予定額は2019年までで、秘匿の値は NULL です
  - 地域コードは各年の時点のもので、合併で消えたコードは soumu.code.municipality にありません
keywords:
  - e-stat
  - 建築着工統計調査
  - 建築着工
  - 着工床面積
  - 建築物
  - 用途
  - 市区町村
sources:
  - path: https://www.e-stat.go.jp/dbview?sid=0004019181
  - path: https://www.e-stat.go.jp/dbview?sid=0003114492
fields:
  - name: area
    title: 地域コード
    description: "地域コード（5桁）。統計に用いる標準地域コードと同じ体系で、soumu.code.municipality の area_code と結合できる。東京の特別区は 13101〜13123 の区ごとに入り、特別区部（13100）の合計行は無い。政令指定都市は市の行（01100 など）と区の行の両方がある"
    semantic: {role: entity, name: city}
  - name: area_name
    title: 地域名
    description: "area に対応する地域名。都道府県名は付かない。浜松市の区は「中区（～R5.12 行政区再編前）」「中央区（R6.1～ 行政区再編後）」のように再編の前後が名称に入る"
  - name: area_level
    title: 地域の粒度
    description: "municipality=市区町村（政令指定都市と特別区を含む）、ward=政令指定都市の区。日本全域をちょうど1回覆うのは municipality だけで、ward はその内訳"
  - name: parent_area
    title: 親の地域コード
    description: "1つ上の地域コード。市区町村は都道府県（下3桁が000）、区は政令指定都市"
  - name: year
    title: 年
    description: "西暦の年。1月から12月までに着工した分で、年度ではない。2011〜2024で欠けは無い"
  - name: use_code
    title: 用途コード
    description: "用途（大分類）のコード。11=計、12〜75=18の用途。計と内訳が同じ列に並ぶので、用途で合計するときは 11 を除く。計は18用途の合計に一致する（建築物の数・床面積で実測）"
  - name: use_name
    title: 用途
    description: "use_code に対応する用途名。「計」のほかは「Ａ居住専用住宅」のように全角の分類記号が前に付く。Ａ居住専用住宅・Ｂ居住専用準住宅（寄宿舎など）・Ｃ居住産業併用建築物の3つが住宅系で、Ｄ以降は産業別"
  - name: buildings
    title: 建築物の数
    description: "着工した建築物の数（棟）"
  - name: floor_area
    title: 床面積の合計
    description: "着工した建築物の床面積の合計（平方メートル）。2018年の新潟市北区 Ｎ教育，学習支援業用建築物の1セルだけ秘匿で NULL"
  - name: construction_cost
    title: 工事費予定額
    description: "工事費予定額（万円）。2019年まで。2020年以降は全行 NULL。2019年までも秘匿の値が NULL で、用途の内訳の23%、計の2%が NULL になる"
themes: [housing_land]
---

# 建築着工統計調査（municipality_use）

着工した建築物の数・床面積・工事費予定額を、市区町村別・政令指定都市の区別・用途（大分類）別に収録します。

- `e_stat.building_starts.municipality_use`: 505,153行

収録は2011〜2024年で、1月から12月までに着工した分の年次の値です。市区町村の行を足すと全国の値に一致します。

出典: [国土交通省 建築着工統計調査](https://www.e-stat.go.jp/statistics/00600120)

## 製造業用の建築物の着工床面積が大きい市区町村

```sql
SELECT area, area_name, floor_area, buildings
FROM e_stat.building_starts.municipality_use
WHERE year = 2024 AND use_code = '34' AND area_level = 'municipality'
ORDER BY floor_area DESC
LIMIT 5
```

2024年は合志市の241,342平方メートル（20棟）が最も大きく、浜松市・守山市・宇都宮市・姫路市と続きます。

## 住宅の着工床面積の推移

```sql
SELECT year,
    sum(floor_area) FILTER (WHERE use_code = '12') AS residential,
    sum(floor_area) FILTER (WHERE use_code = '11') AS total
FROM e_stat.building_starts.municipality_use
WHERE area_level = 'municipality'
GROUP BY year
ORDER BY year
```

居住専用住宅は2011年の74,633,440平方メートルから2024年の59,571,227平方メートルへ20.2%減り、建築物全体（18.8%減）より減り方が大きくなっています。

## 計と内訳が同じ列に並ぶ

用途の計（use_code = '11'）と政令指定都市の区（area_level = 'ward'）が内訳と同じ列にあるので、絞らずに足すと二重に数えます。用途で足すときは計を除き、地域で足すときは area_level = 'municipality' に絞ります。

## 着工の無い年の地域は行が無い

着工が1棟も無かった年の地域は行がありません。年ごとの市区町村の数は1,716〜1,735の範囲で動きます。

## 工事費予定額は2019年まで

2020年以降の市区町村別の表には工事費予定額がないので、2020年以降は NULL です。2019年までも原典の「＊」（秘匿）は NULL で、用途の内訳の23%、計の2%にあたります。

## 地域コードは各年の時点のもの

合併で消えた市町村のコードと、浜松市の行政区再編（2024年1月）前の区のコードは、それぞれの年の行に残っています。現行の soumu.code.municipality にはこれらのコードがありません。

## 補足: 建築着工統計調査 市区町村別・用途別の建築着工（building_starts スキーマ）

国土交通省の建築着工統計調査のうち、建築物着工統計の市区町村別・用途別（大分類）の年次の表です。
505,153行で、市区町村の行を足すと全国の値に一致します。

## 補足: building_starts.municipality_use

建築基準法の建築工事届にもとづく全数の集計で、床面積の合計が10平方メートルを超える建築物が対象。
用途は18区分（居住専用住宅・製造業用・宿泊業，飲食サービス業用など）と、その計。
収録は2011年〜2024年の14年、505,153行。
地域は市区町村（特別区を含む。
1年に1,716〜1,735）と政令指定都市の区（170〜175）。
市区町村の行を足すと全国の値に一致する（建築物の数・床面積とも全年・全用途で実測）。
2019年までも秘匿（原典の「＊」）が用途の内訳の23%にあり、その値は NULL。
2024年の地域コードはすべて soumu.code.municipality に載る。
