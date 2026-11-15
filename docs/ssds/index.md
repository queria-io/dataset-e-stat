# 社会・人口統計体系（SSDS）

社会・人口統計体系（SSDS）の指標を、11分野（A〜K）× 都道府県・市区町村の22テーブルに収録しています。都道府県のテーブルは `e_stat.ssds.<分野>_pref_<名前>`、市区町村のテーブルは `e_stat.ssds.<分野>_municipal_<名前>` です。分野ごとの代表的な指標と SQL の例は、各分野の都道府県のテーブル（例: [A 人口・世帯](a_pref_population.md)）の使い方ガイドにあります。

出典: [社会・人口統計体系（SSDS）](https://www.e-stat.go.jp/statistics/00200502)

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
```

```sql
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

## 補足: データ出典

[e-Stat（政府統計の総合窓口）](https://www.e-stat.go.jp/)の API から取得した「社会・人口統計体系」のデータです。
都道府県別・市区町村別に、以下の11カテゴリの統計指標を収録しています。

## 補足: テーブル構造

全テーブル共通のカラム構成です。

- cat01: 分類事項の項目符号（例: 「J1102」）
- item_name: 分類事項名（例: 「J1102_現に保護を受けた生活保護被保護実世帯数」）
- cat01_parent: 上位項目の符号（5桁の項目は NULL）
- area / area_name: 地域コード / 地域名
- time_name: 時間軸名（例: 「2020年度」）
- year: time_name から抽出した西暦4桁
- unit: 単位（例: 「人」「km2」）
- value: 統計値

項目と副区分が同じ列に混在するので、`cat01_parent` で切り分けます。

副区分が親を分割しているとは限りません。A1101 のように男女で分割される系統もあれば、
J1102 のように「うち」項目だけが並んでいて親に届かない系統もあります。
親自身がデータを持たないこともあります（分類項目名だけが定義され、副区分のみ
公開されている系統が 621 件）。

地域も同様に、都道府県版は全国計（area = 00000）を、市区町村版は政令指定都市の
合計行と行政区をどちらも含みます。市区町村単位で数えるときは
`code.municipality` の `is_municipality` で絞ります。

## 補足: 指標別の収録年（ssds.series_coverage）

収録年は指標ごとに違います。毎年更新される系列と、国勢調査ベースで5年ごとの系列が
同じテーブルに混在するため、テーブル全体の `MAX(year)` は「どこまで新しいか」の
答えになりません。`a_pref_population` はテーブルとしては 2025 年まで入っていますが、
2025 年に届く指標は 594 のうち 12 だけで、307 は 2020 年で止まります。

`ssds.series_coverage` が指標ごとの収録年を持っています。22テーブル分をまとめた
約 5,000 行の表で、22テーブルを走査せずに引けます。

```sql
SELECT table_name, cat01, item_name, min_year, max_year, year_count
FROM e_stat.ssds.series_coverage
WHERE table_name = 'c_municipal_economy'
  AND cat01 IN ('C120110', 'C120120')
```

`year_count` が `max_year - min_year + 1` に満たなければ、その系列は年が飛んでいます。

収録年は地域をまたいだ和です。`max_year` は「どこかの地域で」その年まで入っていることを
表すので、地域を1つに絞って使うときは、その地域にその年の行があるかを別に確かめます
（`c_municipal_economy` では199指標中114指標で最新年が地域ごとに違います）。

## 補足: ssds.item_catalog

社会・人口統計体系（SSDS）の基礎データ項目一覧。
都道府県・市区町村の全22表で利用可能な統計指標とその分類体系を提供する。

## 補足: ssds.series_coverage

社会・人口統計体系（SSDS）22表の指標（cat01）ごとに、値が入っている最も古い年と最も新しい年、 および年数を収録する。
指標を指定してこの表を引くと、実データを走査せずに収録年が分かる。
