---
$schema: https://queria.io/schemas/table/v1.json
table: census.census_municipality
title: 市区町村別 人口・世帯・人口増減（令和2年国勢調査）
description: |-
  令和2年国勢調査の、全国・都道府県・市区町村ごとの人口・世帯数・5年前との増減・面積・人口密度を1行に持つテーブルです。

  - 全国・都道府県・市区町村などの行が同じ列に並ぶので、area_level で1つの粒度に絞ってから合計してください
  - area は標準地域コード（5桁）で、6桁の全国地方公共団体コードとは別体系です
keywords:
  - e-stat
  - 国勢調査
  - 市区町村
  - 都道府県
  - 人口
  - 世帯
  - 人口密度
  - 人口増減
temporal_coverage: {start: "2020", end: "2020"}
sources:
  - path: https://www.e-stat.go.jp/statistics/00200521
fields:
  - name: area
    title: 標準地域コード（5桁）
    description: 標準地域コード。全国は 00000、都道府県は 13000 のように市区町村部が 000。census_small_area_* の市区町村行・boundary.small_area の key_code の上位5桁・soumu.code.municipality の area_code と同じ体系。全国地方公共団体コード（6桁）とは別体系
    semantic: {role: entity, name: city}
  - name: area_name
    title: 地域名
    description: 地域の名称（全国／東京都／特別区部／千代田区／札幌市／札幌市中央区 など）。2000年市区町村の行は「（旧：戸井町）」のように括弧付きで入る
  - name: area_level
    title: 地域の粒度
    description: 'area の粒度。national=全国（1）、prefecture=都道府県（47）、city=市・特別区部（793）、ward=政令指定都市の区と特別区（198）、town_village=町村（926）、former_municipality=2000年（平成12年）の市区町村（2,121）。日本全域をちょうど1回覆うのは prefecture だけ、または city と town_village の組だけで、どちらも人口の合計が全国の 126,146,099 に一致する。ward は city の内訳（例: 千代田区は特別区部の内訳）、former_municipality は現行市区町村を2000年の区域で組み替えた再掲で、いずれも足すと二重に数える'
  - name: parent_area
    title: 上位地域の標準地域コード
    description: 1つ上の階層の area。都道府県の親は全国、市・町村の親は都道府県、政令指定都市の区の親はその市、特別区の親は特別区部（13100）。全国は NULL。2000年市区町村の親は都道府県で、現行の市区町村ではない
  - name: population
    title: 人口
    description: 人口（人）。2020年10月1日現在。全国で 126,146,099
  - name: population_male
    title: 人口（男）
    description: 男の人口（人）。population_male + population_female = population が全行で成り立つ
  - name: population_female
    title: 人口（女）
    description: 女の人口（人）
  - name: households
    title: 世帯数
    description: 世帯数（世帯）。一般世帯と施設等の世帯の合計。全国で 55,830,154
  - name: households_general
    title: 一般世帯数
    description: 一般世帯数（世帯）。全国で 55,704,949
  - name: households_institutional
    title: 施設等の世帯数
    description: 施設等の世帯数（世帯）。寮・病院・施設・自衛隊営舎などに住む世帯
  - name: household_members
    title: 世帯人員
    description: 世帯人員（人）。全行で population と一致する（国勢調査は世帯を単位に人を数えるため）
  - name: household_members_general
    title: 一般世帯人員
    description: 一般世帯の世帯人員（人）。household_members_general ÷ households_general が1世帯当たり人員
  - name: household_members_institutional
    title: 施設等の世帯人員
    description: 施設等の世帯の世帯人員（人）
  - name: population_2015
    title: 2015年（平成27年）の人口（組替）
    description: 平成27年国勢調査の人口を2020年の市区町村の区域に組み替えた値（人）。東日本大震災で全町避難が続いた富岡町・大熊町・双葉町・浪江町の4町は原典が「-」で、NULL になる
  - name: households_2015
    title: 2015年（平成27年）の世帯数（組替）
    description: 平成27年国勢調査の世帯数を2020年の市区町村の区域に組み替えた値（世帯）。population_2015 と同じ4町が NULL
  - name: population_change_5y
    title: 5年間の人口増減数
    description: 2015年からの人口増減数（人）。population - population_2015 に等しい。ただし population_2015 が NULL の4町では原典が2015年を0として増減数を出しているため、実質的に2020年の人口そのもの（双葉町は0）で、増減として読めない
  - name: population_change_rate_5y
    title: 5年間の人口増減率
    description: 2015年からの人口増減率（％）。population_2015 が NULL の4町は原典も「-」で NULL
  - name: household_change_5y
    title: 5年間の世帯増減数
    description: 2015年からの世帯増減数（世帯）。population_change_5y と同じく、4町では増減として読めない
  - name: household_change_rate_5y
    title: 5年間の世帯増減率
    description: 2015年からの世帯増減率（％）。4町は NULL
  - name: sex_ratio
    title: 人口性比
    description: 女100人に対する男の数。population_male ÷ population_female × 100。人口が非公表の双葉町のみ NULL
  - name: area_km2
    title: 面積（参考）
    description: 面積（km2）。北方領土と竹島を含む。全国で 377,976.41。population_density の分母はこれらを除いた面積なので、population ÷ area_km2 は population_density と一致しない（全国で約4,984km2、根室市で約95km2、隠岐の島町で約0.35km2の差）
  - name: population_density
    title: 人口密度
    description: 1km2当たりの人口。原典の公表値で、分母は北方領土と竹島を除いた面積。人口が非公表の双葉町は 0.0 が入る（0人ではない）
themes: [population]
---

# 令和2年国勢調査 市区町村別 基本集計（census スキーマ）

市区町村・都道府県の単位で、人口・世帯・5年間の増減・面積・人口密度をまとめたテーブルです。[小地域集計](../../../docs/census/index.md)より粗い粒度で、人口ランキングや増減率の比較のように地域を並べて見たいときに使います。

テーブルは `census_municipality` の1つです。原典の3つの統計表（第1-1-1表 男女別人口、第1-1-2表 世帯の種類別世帯数及び世帯人員、第1-1-3表 人口増減・面積・人口密度）を地域1行の横持ちにまとめてあります。同じ粒度で就業の側面を見るときは[就業状態等基本集計](census_municipality_labor_force.md)、昼間の人口や通勤・通学の行き先を見るときは[昼夜間人口と通勤・通学流動](census_commuting_flow.md)を使います。

令和7年（2025年）の同じ集計は `census_municipality_2025`（列は同じ）と、年齢別の `census_municipality_age_2025` にあります。下の「令和7年（2025年）の表」を見てください。

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

`area` は標準地域コード（5桁）です。`soumu.code.municipality` の `area_code`、`census_small_area_*` の市区町村行、`boundary.small_area` の `key_code` の上位5桁と同じ体系です。

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

## 令和7年（2025年）の表

`census_municipality_2025` は令和7年国勢調査の同じ集計で、列は `census_municipality` と同じです。5年前の列だけが `population_2020` / `households_2020` になります。粒度の切り分けも同じで、2025年は全国の人口が 122,972,528 人です。

| area_level | 地域数 | 人口の合計 | 2020年の表にもある地域 |
|-----------|-------:|----------:|---------------------:|
| national | 1 | 122,972,528 | 1 |
| prefecture | 47 | 122,972,528 | 47 |
| city | 793 | 113,209,635 | 793 |
| town_village | 926 | 9,762,893 | 926 |
| ward | 194 | 37,609,400 | 191 |
| former_municipality | 2,121 | 51,093,021 | 2,121 |

2020年と2025年で地域コードが違うのは浜松市の区だけです。2024年に7区が中央区・浜名区・天竜区の3区に再編されたため、2025年の `ward` のうち `22138`〜`22140` の3行は2020年の表とつながりません（2020年の7区は2025年の表にありません）。浜松市そのもの（`22130`）はつながります。

```sql
-- 市区町村の 2020年→2025年 の人口の変化（全域を覆い、重複しない）
SELECT n.area_name, o.population AS population_2020, n.population AS population_2025,
       n.population - o.population AS change
FROM e_stat.census.census_municipality_2025 n
JOIN e_stat.census.census_municipality o USING (area)
WHERE n.area_level IN ('city', 'town_village')
ORDER BY change
LIMIT 10
```

`census_municipality_age_2025` は同じ 4,082 地域の5歳階級別人口で、1地域につき `age_code` 01（0〜4歳）〜21（100歳以上）と 22（年齢不詳）の22行です。男女と「うち日本人」は列に分かれています。22行を足すと `census_municipality_2025` の `population` と一致します（全国・東京都で確認）。年齢不詳は全国で 3,289,734 人、東京都で 618,507 人と多いので、年齢構成の割合を出すときは分母から不詳を外すかどうかを決めてから使ってください。

```sql
-- 都道府県別の65歳以上の割合（年齢不詳を分母から外す）
SELECT area_name,
       ROUND(100.0 * SUM(population) FILTER (WHERE age_from >= 65)
             / SUM(population) FILTER (WHERE age_code <> '22'), 1) AS aged_pct
FROM e_stat.census.census_municipality_age_2025
WHERE area_level = 'prefecture'
GROUP BY area_name
ORDER BY aged_pct DESC
LIMIT 5
```

## 補足: 国勢調査 市区町村別 基本集計（census スキーマ）

令和2年国勢調査 人口等基本集計の第1-1-1表・第1-1-2表・第1-1-3表を、地域1行の
横持ちにまとめた census_municipality です。人口・男女別人口・世帯数・世帯人員・
5年前との人口／世帯の増減・人口性比・面積・人口密度を持ちます。

area は全国・都道府県・市区町村・政令指定都市の区・2000年（平成12年）市区町村が
同じ列に縦に並びます。粒度は area_level で判別します。

面積（area_km2）は北方領土と竹島を含みますが、人口密度（population_density）の
分母はそれらを除いた面積です。`population / area_km2` は原典の人口密度と一致しません
（全国で約4,984km2、根室市で約95km2の差）。

## 補足: 国勢調査 市区町村別 基本集計 令和7年（census スキーマ）

令和7年国勢調査 人口等基本集計（2026年9月公表）から作った2表です。

| テーブル | 内容 |
|---------|------|
| census_municipality_2025 | 人口・男女別人口・世帯数・世帯人員・5年前（2020年）との増減・人口性比・面積・人口密度（地域1行） |
| census_municipality_age_2025 | 男女・年齢（5歳階級）別人口。うち日本人の列も持つ（地域 × 年齢22区分） |

census_municipality_2025 は令和2年の census_municipality と列が同じで、5年前の列だけが
population_2020・households_2020 になります。area も同じ標準地域コード（5桁）で、
area_level の切り分けも同じです（2025年は ward が 194）。2つの表は area で結合して
比べられます。2020年から変わった地域コードは浜松市の区だけです（2024年の区の再編で
7区から中央区・浜名区・天竜区の3区になった）。

census_municipality_age_2025 は原典の年齢の総数と再掲（15歳未満・65歳以上など）を持たず、
5歳階級21区分と年齢不詳だけを持ちます。22行を足すと census_municipality_2025 の
population に一致します。65歳以上は `age_from >= 65` で足します。

この2表は毎日の更新（CI）では e-Stat から取らず、手元で1回だけ取り込んでいます
（下の「手元で1回だけ取り込む統計表」）。

## 補足: census.census_municipality

census スキーマの他の表が町丁・字等の粒度なのに対し、こちらは市区町村・都道府県の粒度。

## 補足: census.census_municipality_2025

出典: 総務省統計局 令和7年国勢調査 人口等基本集計（統計表 0004065881・0004065901・0004065882）。

## 補足: census.census_municipality_age_2025

1地域につき 0〜4歳から100歳以上までの21区分と年齢不詳の計22行で、男女と「うち日本人」は列に分けてある。
原典にある年齢の総数と再掲（15歳未満・65歳以上など）は二重に数えないよう持たない。
外国人と国籍不詳は population - population_japanese で、2つは分けられない。
令和2年の市区町村別の年齢は census_small_area_age の5桁の行にある（区分の形は違う）。
