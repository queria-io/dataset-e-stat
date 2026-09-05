---
title: 市区町村別 基本集計（国勢調査）
order: 15
---

# 令和2年国勢調査 市区町村別 基本集計（census スキーマ）

市区町村・都道府県の単位で、人口・世帯・5年間の増減・面積・人口密度をまとめたテーブルです。[小地域集計](/cookbook/e_stat/census)より粗い粒度で、人口ランキングや増減率の比較のように地域を並べて見たいときに使います。

テーブルは `census_municipality` の1つです。原典の3つの統計表（第1-1-1表 男女別人口、第1-1-2表 世帯の種類別世帯数及び世帯人員、第1-1-3表 人口増減・面積・人口密度）を地域1行の横持ちにまとめてあります。同じ粒度で就業の側面を見るときは[就業状態等基本集計](/cookbook/e_stat/census-employment)、昼間の人口や通勤・通学の行き先を見るときは[昼夜間人口と通勤・通学流動](/cookbook/e_stat/census-commuting)を使います。

| 列のグループ | 列 |
|-------------|-----|
| 地域 | area / area_name / area_level / parent_area |
| 人口 | population / population_male / population_female |
| 世帯 | households / households_general / households_institutional |
| 世帯人員 | household_members / household_members_general / household_members_institutional |
| 5年間の増減 | population_2015 / households_2015 / population_change_5y / population_change_rate_5y / household_change_5y / household_change_rate_5y |
| その他 | sex_ratio / area_km2 / population_density |

出典: [令和2年国勢調査 人口等基本集計](https://www.e-stat.go.jp/statistics/00200521)

## 粒度を混ぜると二重に数える

`area` には全国・都道府県・市区町村・区・2000年（平成12年）の市区町村が縦に並んでいます。粒度は `area_level` で判別します。

| area_level | 内容 | 地域数 | 人口の合計 |
|-----------|------|-------:|----------:|
| national | 全国 | 1 | 126,146,099 |
| prefecture | 都道府県 | 47 | 126,146,099 |
| city | 市・特別区部 | 793 | 115,757,942 |
| town_village | 町村 | 926 | 10,388,157 |
| ward | 政令指定都市の区・特別区 | 198 | 37,532,334 |
| former_municipality | 2000年（平成12年）市区町村 | 2,121 | 53,303,248 |

日本全域をちょうど1回覆うのは `prefecture` だけ、または `city` と `town_village` の組だけです。

`ward` は `city` の内訳です。札幌市中央区は札幌市の、千代田区は特別区部の内訳にあたります。`former_municipality` は現行の市区町村を2000年の区域で組み替えた再掲で、地域コードは現行と重複しません（「（旧：戸井町）」のように名前で見分けられます）。どちらも `city` や `town_village` と一緒に足すと二重に数えます。

```sql
-- 市区町村単位の人口ランキング（全域を覆い、重複しない）
SELECT area_name, population, population_density
FROM e_stat.census.census_municipality
WHERE area_level IN ('city', 'town_village')
ORDER BY population DESC
LIMIT 10
```

東京23区は `city` ではなく `ward` です。`city` に入るのは23区をまとめた「特別区部」（`13100`）1行で、23区は `parent_area = '13100'` の `ward` として別にあります。23区を1つずつ並べたいときは `ward` を使います。

```sql
-- 東京23区の人口
SELECT area_name, population, ROUND(population_change_rate_5y, 2) AS change_pct
FROM e_stat.census.census_municipality
WHERE parent_area = '13100'
ORDER BY population DESC
```

## 5年間の増減

`population_2015` は平成27年国勢調査の人口を2020年の市区町村の区域に組み替えた値です。市町村合併があっても2020年の区域どうしで比較できます。

```sql
-- 人口10万人以上で増加率の高い市区町村
SELECT area_name, population, ROUND(population_change_rate_5y, 2) AS change_pct
FROM e_stat.census.census_municipality
WHERE area_level IN ('city', 'town_village')
  AND population >= 100000
  AND population_2015 IS NOT NULL
ORDER BY change_pct DESC
LIMIT 5
```

東日本大震災で全町避難が続いた富岡町・大熊町・双葉町・浪江町の4町は、2015年の人口・世帯数と増減率が原典で「-」のため NULL です。増減数（`population_change_5y` / `household_change_5y`）のほうは原典が2015年を0として出しているので、増減としては読めません。上のクエリのように `population_2015 IS NOT NULL` で外します。

双葉町は2020年の人口・世帯数も非公表で NULL です。人口密度だけ 0.0 が入りますが、0人という意味ではありません。

## 面積と人口密度の分母は違う

`area_km2` は北方領土と竹島を含みます。一方 `population_density` は原典の公表値で、分母はそれらを除いた面積です。`population / area_km2` を人口密度として使うと値がずれます。

| 地域 | area_km2 | 人口密度の分母（逆算） | 差 |
|------|---------:|---------------------:|----:|
| 全国 | 377,976.41 | 372,992.6 | 4,983.81 |
| 北海道 | 83,424.44 | 78,447.66 | 4,976.78 |
| 根室市 | 506.25 | 411.29 | 94.96 |
| 隠岐の島町 | 242.82 | 242.47 | 0.35 |

人口密度は公表値の `population_density` をそのまま使ってください。

## 世帯の内訳

`households` は一般世帯と施設等の世帯の合計です。施設等の世帯は寮・病院・施設・自衛隊営舎などに住む世帯で、1世帯当たり人員のような指標を出すときは一般世帯だけを使います。

```sql
-- 都道府県別の1世帯当たり人員（一般世帯）
SELECT area_name,
       ROUND(household_members_general * 1.0 / households_general, 2) AS members_per_household
FROM e_stat.census.census_municipality
WHERE area_level = 'prefecture'
ORDER BY members_per_household
LIMIT 5
```

`household_members`（世帯人員の総数）は全行で `population` と一致します。国勢調査が世帯を単位に人を数えているためで、別の指標ではありません。

## 他のテーブルとつなぐ

`area` は標準地域コード（5桁）です。`code.municipality` の `area_code`、`census_small_area_*` の市区町村行、`boundary.small_area` の `key_code` の上位5桁と同じ体系です。

小地域集計と突き合わせるときは、`census_small_area_*` の9桁コードの上位5桁で結合します。

```sql
-- 町丁・字等の合計と市区町村の公表値を突き合わせる
SELECT m.area_name, m.population AS published, SUM(s.value) AS from_small_area
FROM e_stat.census.census_municipality m
JOIN e_stat.census.census_small_area_age s
  ON SUBSTR(s.area, 1, 5) = m.area AND s.cat01 = '0010' AND s.area_level = 'small_area'
WHERE m.area_level IN ('city', 'town_village', 'ward') AND m.area LIKE '08%'
GROUP BY m.area_name, m.population
ORDER BY published DESC
```

小地域集計は政令指定都市を区の単位で持っています。北海道でいうと `01101` 札幌市中央区の
行はありますが、市全体の `01100` 札幌市はありません。政令指定都市と特別区部の行
（`area_level = 'city'` のうち下位に `ward` を持つもの）はこの結合では落ちるので、
`ward` を含めた粒度で突き合わせてください。

`lg_code` や `address_br` が使う全国地方公共団体コードは6桁で、末尾にチェックデジットが付く別の体系です。結合するときは桁と体系を揃えてください。
