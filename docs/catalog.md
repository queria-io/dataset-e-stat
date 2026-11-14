# 統計表カタログと指標定義

どんな統計表・指標が収録されているかを調べるためのメタデータです。

- `e_stat.main.stats_catalog`: 統計表のカタログ（政府統計名・分野・集計地域区分などで横断検索）
- `e_stat.ssds.item_catalog`: 社会・人口統計体系の指標定義（`item_code` が各カテゴリテーブルの `cat01`）
- `e_stat.ssds.series_coverage`: 指標ごとの収録年（`cat01` 単位の `min_year` / `max_year`）

## 統計表を探す: stats_catalog

```sql
SELECT stat_name, table_title, gov_org_name, collect_area, cycle
FROM e_stat.main.stats_catalog
WHERE table_title LIKE '%人口%'
LIMIT 20
```

主なカラム: `stats_data_id`（統計表ID）, `stat_name`（政府統計名）, `gov_org_name`（作成機関）, `table_title`（統計表題名）, `main_category` / `sub_category`（統計分野）, `collect_area`（集計地域区分）, `cycle`（周期）。

## 指標コードを探す: item_catalog

SSDS の各カテゴリテーブルで使う `cat01` は、ここで `item_name` を検索して特定します。`item_code` がそのまま `cat01` です。`#` で始まる item_code は算出指標の定義で、各カテゴリテーブルには収録されていないため除外します。

```sql
SELECT DISTINCT table_title, item_code, item_name, unit
FROM e_stat.ssds.item_catalog
WHERE item_name LIKE '%就業者%'
  AND item_code NOT LIKE '#%'
ORDER BY item_code
LIMIT 20
```

## 分野ごとの指標数

```sql
SELECT table_title, COUNT(DISTINCT item_code) AS item_count
FROM e_stat.ssds.item_catalog
WHERE item_code NOT LIKE '#%'
GROUP BY table_title
ORDER BY item_count DESC
```

## 指標がいつからいつまで入っているか: series_coverage

収録年は指標ごとに違います。毎年更新される系列と、国勢調査ベースで5年ごとの系列が
同じテーブルに混在するため、テーブル全体の `MAX(year)` は「どこまで新しいか」の
答えになりません。`a_pref_population` はテーブルとしては 2025 年まで入っていますが、
2025 年に届く指標は 594 のうち 12 だけで、307 は 2020 年で止まります。

`series_coverage` は 22 テーブル分の指標をまとめた約 5,000 行の表です。集計対象の
テーブルを走査せずに、指標を指定して収録年を引けます。

```sql
SELECT table_name, cat01, item_name, min_year, max_year, year_count
FROM e_stat.ssds.series_coverage
WHERE table_name = 'c_municipal_economy'
  AND cat01 IN ('C120110', 'C120120')
```

`year_count` は値が入っている年の数です。`max_year - min_year + 1` に満たなければ、
その系列は年が飛んでいます。

```sql
-- 5年ごとにしか入っていない指標を探す
SELECT table_name, cat01, item_name, min_year, max_year, year_count
FROM e_stat.ssds.series_coverage
WHERE table_name = 'a_pref_population'
  AND year_count * 4 < max_year - min_year
ORDER BY cat01
```

`min_year` / `max_year` は値が入っている年で数えています。元データが「-」「X」で
`value` が NULL の行は含みません。

収録年は地域をまたいだ和です。`max_year` は「どこかの地域で」その年まで入っている
ことを表すので、地域を1つに絞って描くときは、その地域にその年の行があるかを
別に確かめてください（`c_municipal_economy` では199指標中114指標で最新年が
地域ごとに違います）。

```sql
-- 指標と地域を決めてから、その地域の最新年を確かめる
SELECT max(year) AS max_year
FROM e_stat.ssds.c_municipal_economy
WHERE cat01 = 'C3107' AND area = '13101' AND value IS NOT NULL
```
