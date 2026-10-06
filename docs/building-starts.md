---
title: 市区町村別・用途別の建築着工（建築着工統計調査）
order: 29
---

# 建築着工統計調査（municipality_use）

着工した建築物の数・床面積・工事費予定額を、市区町村別・政令指定都市の区別・用途（大分類）別に収録します。

- `e_stat.building_starts.municipality_use`: 505,153行

収録は2011〜2024年で、1月から12月までに着工した分の年次の値です。市区町村の行を足すと全国の値に一致します。

出典: [国土交通省 建築着工統計調査](https://www.e-stat.go.jp/statistics/00600120)

## カラム構成

- area / area_name: 地域コード（5桁） / 地域名。code.municipality の area_code と結合できる
- area_level: 地域の粒度（`municipality` 市区町村・`ward` 政令指定都市の区）
- parent_area: 1つ上の地域コード（市区町村は都道府県、区は政令指定都市）
- year: 年（2011〜2024）
- use_code / use_name: 用途（`11` 計・`12` Ａ居住専用住宅・`34` Ｆ製造業用建築物など18区分）
- buildings: 建築物の数（棟）
- floor_area: 床面積の合計（平方メートル）
- construction_cost: 工事費予定額（万円）。2019年まで

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

合併で消えた市町村のコードと、浜松市の行政区再編（2024年1月）前の区のコードは、それぞれの年の行に残っています。現行の code.municipality にはこれらのコードがありません。
