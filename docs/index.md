---
title: 概要と使い方
order: 0
---

# e-Stat データセットの使い方

e-Stat（政府統計の総合窓口）の API と統計GIS から取得した政府統計データです。中心となるのは社会・人口統計体系（SSDS）で、都道府県・市区町村それぞれ11分野の統計指標を共通のテーブル構造で収録しています。加えて消費者物価指数、統計表のメタデータ、令和2年国勢調査の市区町村別・小地域（町丁・字等）集計、昼夜間人口と通勤・通学流動、境界データを収録します。

出典: [e-Stat](https://www.e-stat.go.jp/) / [社会・人口統計体系（SSDS）](https://www.e-stat.go.jp/statistics/00200502)

## スキーマとテーブルの構成

| スキーマ | 内容 |
|---------|------|
| ssds | 社会・人口統計体系。11分野 × 都道府県/市区町村 = 22テーブル + 指標定義 item_catalog + 指標別の収録年 series_coverage |
| cpi | 消費者物価指数 price_index |
| main | 統計表カタログ stats_catalog |
| census | 令和2年国勢調査 小地域集計 census_small_area_*（年齢・世帯・住宅・産業）、市区町村別 基本集計 census_municipality、市区町村別 就業状態等基本集計 census_municipality_labor_force / census_municipality_employment_status、昼夜間人口 census_municipality_daytime_population、通勤・通学流動 census_commuting_flow、1kmメッシュ別昼間人口 daytime_population_mesh_1km |
| boundary | 令和2年国勢調査 町丁・字等別境界 small_area、1kmメッシュ境界 mesh_1km |
| code | 統計に用いる標準地域コード municipality と、その変更（廃置分合）履歴 municipality_change |

11分野（A〜K）の詳細は各カテゴリのガイドを参照してください。市区町村・都道府県を並べて比べたいときは[市区町村別 基本集計](/cookbook/e_stat/census-municipality)、働いているかどうかや働き方で比べたいときは[就業状態等基本集計](/cookbook/e_stat/census-employment)、昼間に人が集まる街を見たいときや通勤・通学の行き先を見たいときは[昼夜間人口と通勤・通学流動](/cookbook/e_stat/census-commuting)、市区町村より細かい粒度で見たいときは[小地域集計](/cookbook/e_stat/census)、昼と夜で人の分布を見分けたいときは[1kmメッシュ別 昼間人口](/cookbook/e_stat/mesh-daytime)、地図に載せるときは[境界データ](/cookbook/e_stat/boundary)を参照してください。

## SSDS 共通のカラム構成

ssds スキーマの22テーブルはすべて同じ9カラムです。指標を `cat01`（分類事項コード）で絞り込み、`area_name`（地域）と `year`（年）で必要な行を取り出すのが基本です。

- cat01: 分類事項の項目符号（例: `A1101` = 総人口）
- item_name: 分類事項名（例: `A1101_総人口`）
- cat01_parent: 上位項目の符号（5桁の項目は NULL）
- area: 地域コード（全国は `00000`、都道府県は `13000` のような5桁）
- area_name: 地域名（`全国` / `東京都` など）
- time_name: 時間軸名（例: `2020年度`）
- year: 年
- unit: 単位（例: `人`）
- value: 統計値

`unit` は指標ごとに違います（`人` / `世帯` / `千円` / `％` など）。`cat01` を絞らずに `value` を合計しても意味を持ちません。

## 行の粒度

ssds の22テーブルは `cat01` × `area` × `time_name` で一意です。同じ指標・同じ地域・同じ時点の行は1行しかないので、`SUM` や `JOIN` の前に重複を取り除く必要はありません。

2026年7月まで、同一条件で値の等しい行が最大3行返ることがありました。現在は解消しています。`MAX(value)` や `DISTINCT` で重複を除いている既存のクエリは、1行に対する演算になるだけなのでそのままでも正しく動きます。

なお `area_name` には集計行が含まれます。都道府県テーブルには `全国`、市区町村テーブルには政令指定都市の市全体（例: `愛知県 名古屋市`）と `東京都 特別区部` が入っており、個別の地域と一緒に `SUM` すると二重計上になります。

```sql
-- 全国の集計行を除いて都道府県だけを合計する
SELECT year, SUM(value) AS population
FROM e_stat.ssds.a_pref_population
WHERE cat01 = 'A1101' AND area_name <> '全国'
GROUP BY year
ORDER BY year
```

市区町村テーブルは政令指定都市の合計行（`01100` 札幌市）と行政区（`01101` 中央区）が同居します。市区町村単位で数えるときは `code.municipality` の `is_municipality` で絞ります。

```sql
-- 政令市を1団体として数え、行政区は数えない
SELECT m.pref_name, COUNT(*) AS municipalities
FROM e_stat.ssds.a_municipal_population p
JOIN e_stat.code.municipality m ON p.area = m.area_code
WHERE p.cat01 = 'A1101' AND p.year = 2020 AND m.is_municipality
GROUP BY m.pref_name
ORDER BY municipalities DESC
LIMIT 5
```

## 項目符号の構造

項目符号は[総務省の定義](https://www.stat.go.jp/data/ssds/2.html)で桁数が決まっています。分野1文字 + 大分類1桁 + 小分類1桁 + 項目2桁 の5桁が項目で、その下に副区分が付いたものが7桁以上です。副区分は1階層だけなので、5桁を超えるコードの親は先頭5桁になります。

```
A1101      総人口          （項目 = 5桁）
A110101    総人口（男）    （副区分。親は A1101）
```

項目と副区分は同じ列に並ぶので、`LIKE 'J1104%'` で絞ると両方返ってきます。`cat01_parent` で切り分けます。

```sql
-- 項目だけ
SELECT DISTINCT cat01, item_name
FROM e_stat.ssds.j_pref_welfare
WHERE cat01_parent IS NULL

-- 生活保護扶助世帯数（J1104）の副区分だけ
SELECT DISTINCT cat01, item_name
FROM e_stat.ssds.j_pref_welfare
WHERE cat01_parent = 'J1104'
```

ただし副区分が親を分割しているとは限りません。系統によって性質が違います。

| 系統 | 親 | 副区分の合計 | 副区分の性質 |
|------|---:|----------:|-----------|
| A1101 総人口 | 14,047,594 | 14,047,594 | 男女で分割されている |
| J1102 生活保護被保護実世帯数 | 230,706 | 200,729 | 「うち母子世帯」などの部分集合 |

（東京都・2020年度）

副区分を合計して親の代わりにするのは、その系統が分割になっていることを確かめてからにしてください。親の値がある指標は、親をそのまま使うのが安全です。

親自身がデータを持たないこともあります。定義に「大分類、小分類等の分類項目名（データはない）も併せて記載しています」とあるとおりで、`A1601`（未婚人口）のように副区分だけが公開されている系統があります。

## 指標を探す: item_catalog

どの `cat01` を使えばよいかは `item_catalog` を `item_name` で検索して調べます。`item_code` がそのまま各カテゴリテーブルの `cat01` になります。`#` で始まる item_code は算出指標の定義で、各カテゴリテーブルには収録されていないため除外します。

```sql
SELECT DISTINCT table_title, item_code, item_name, unit
FROM e_stat.ssds.item_catalog
WHERE item_name LIKE '%総人口%'
  AND item_code NOT LIKE '#%'
ORDER BY item_code
LIMIT 20
```

## 基本パターン1: 全国の時系列

`area_name = '全国'` で絞るだけです。`cat01` × `area` × `year` で1行なので、集約は要りません。

```sql
SELECT year, value AS population
FROM e_stat.ssds.a_pref_population
WHERE cat01 = 'A1101' AND area_name = '全国'
ORDER BY year
```

## 基本パターン2: 都道府県ランキング（最新年）

最新年をサブクエリで求め、`全国` を除いて並べます。この形はどのカテゴリでも使えます。

```sql
SELECT area_name, value AS population
FROM e_stat.ssds.a_pref_population
WHERE cat01 = 'A1101'
  AND area_name <> '全国'
  AND year = (SELECT MAX(year) FROM e_stat.ssds.a_pref_population WHERE cat01 = 'A1101')
ORDER BY population DESC
LIMIT 10
```

指標によって収録の終わる年が違うため、最新年は `cat01` ごとに求めます。テーブル全体の `MAX(year)` を使うと、その年に値のない指標が空になります。

市区町村単位で見たい場合は `a_municipal_population` 以下の `*_municipal_*` テーブルを使います。`area_name` は `茨城県 つくば市` のように県名と市区町村名が入ります。

## 分野一覧（SSDS）

| 分野 | 都道府県テーブル | 市区町村テーブル |
|------|----------------|----------------|
| A 人口・世帯 | a_pref_population | a_municipal_population |
| B 自然環境 | b_pref_land | b_municipal_land |
| C 経済基盤 | c_pref_economy | c_municipal_economy |
| D 行政基盤 | d_pref_administration | d_municipal_administration |
| E 教育 | e_pref_education | e_municipal_education |
| F 労働 | f_pref_labor | f_municipal_labor |
| G 文化・スポーツ | g_pref_culture | g_municipal_culture |
| H 居住 | h_pref_housing | h_municipal_housing |
| I 健康・医療 | i_pref_health | i_municipal_health |
| J 福祉・社会保障 | j_pref_welfare | j_municipal_welfare |
| K 安全 | k_pref_safety | k_municipal_safety |
