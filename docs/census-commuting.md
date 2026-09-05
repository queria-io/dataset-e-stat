---
title: 昼夜間人口と通勤・通学流動（国勢調査）
order: 17
---

# 令和2年国勢調査 従業地・通学地集計（census スキーマ）

市区町村・都道府県の単位で、昼夜間人口と通勤・通学の流動を持つ2つのテーブルです。[市区町村別 基本集計](/cookbook/e_stat/census-municipality)と[就業状態等基本集計](/cookbook/e_stat/census-employment)が「どこに住んでいるか」を扱うのに対し、こちらは「どこに住む人がどこへ従業・通学しているか」を扱います。昼間にどれだけ人が集まる街かを見たいとき、通勤・通学の行き先を見たいときに使います。

| テーブル | 内容 | 区分の列 | 値 |
|---------|------|---------|----|
| census_municipality_daytime_population | 男女・常住地／従業地・通学地別 人口 | location_code / location | 人口 |
| census_commuting_flow | 常住地 → 従業地・通学地（都道府県）別 通勤者・通学者数 | destination_area / destination_area_name | 通勤者・通学者数 |

どちらも縦持ちで、`census_municipality_daytime_population` が 112,005行（1,965地域 × 男女3 × 常住地従業地19区分）、`census_commuting_flow` が 294,750行（常住地1,965 × 従業地・通学地50 × 男女3）です。年齢は総数のみで、年齢階級別の内訳は含みません。

出典: [令和2年国勢調査 従業地・通学地による人口・就業状態等集計](https://www.e-stat.go.jp/statistics/00200521)（第1-1-1表・第6-1表）

## 粒度を混ぜると二重に数える

`area` は [市区町村別 基本集計](/cookbook/e_stat/census-municipality) と同じ標準地域コード（5桁）で、そこから2000年（平成12年）市区町村の再掲を除いた1,965地域です。`census_commuting_flow` では `area` が常住地を指します。粒度は `area_level` で判別します。

| area_level | 内容 | 地域数 | 夜間人口の合計 |
|-----------|------|-------:|--------------:|
| national | 全国 | 1 | 126,146,099 |
| prefecture | 都道府県 | 47 | 126,146,099 |
| city | 市・特別区部 | 793 | 115,757,942 |
| town_village | 町村 | 926 | 10,388,157 |
| ward | 政令指定都市の区・特別区 | 198 | 37,532,334 |

日本全域をちょうど1回覆うのは `prefecture` だけ、または `city` と `town_village` の組だけです。東京23区が `city` ではなく `ward` に入る点も基本集計と同じで、`city` に入るのは23区をまとめた「特別区部」（`13100`）1行です。

## 夜間人口と昼間人口が同じ列に並ぶ

`census_municipality_daytime_population` は、夜間人口（常住地による人口）側と昼間人口（従業地・通学地による人口）側が同じ列に縦に並びます。どちら側かは `population_base`、階層の深さは `location_level` に出ています。

| location_code | location | level | population_base |
|--------------|----------|------:|-----------------|
| 0 | 常住地による人口（夜間人口） | 1 | nighttime |
| 001 | 従業も通学もしていない | 2 | nighttime |
| 002 | 自市区町村で従業・通学 | 2 | nighttime |
| 0021 / 0022 | 自宅で従業 / 自宅外の自市区町村で従業・通学 | 3 | nighttime |
| 003 | 他市区町村で従業・通学 | 2 | nighttime |
| 0031 / 0032 / 0033 / 0034 | 自市内他区 / 県内他市町村 / 他県 / 従業・通学市区町村「不詳・外国」 | 3 | nighttime |
| 004 | 従業地・通学地「不詳」 | 2 | nighttime |
| 0R1 | （再掲）流出人口 | 2 | nighttime |
| 1 | 従業地・通学地による人口（昼間人口） | 1 | daytime |
| 101 | うち他市区町村に常住 | 2 | daytime |
| 1011 / 1012 / 1013 | 自市内他区 / 県内他市町村 / 他県に常住 | 3 | daytime |
| 102 | うち従業地・通学地「不詳」等で当地に常住している者 | 2 | daytime |
| 1R1 | （再掲）流入人口 | 2 | daytime |

夜間人口の合計に使えるのは `location_level = 2 AND population_base = 'nighttime' AND NOT is_reprint` の4区分（`001` / `002` / `003` / `004`）で、その和が夜間人口に一致します。`population_base` を落とすと昼間人口側の `101` と `102` が混ざります。男女（`sex_code`）も総数・男・女が同じ列に並ぶので、併せて絞ります。

```sql
-- 昼間人口の多い区（政令指定都市の区・特別区）
SELECT area_name, value AS daytime_population
FROM e_stat.census.census_municipality_daytime_population
WHERE sex_code = '0' AND location_code = '1' AND area_level = 'ward'
ORDER BY value DESC
LIMIT 10
```

## 昼夜間人口比率は自分で割る

昼夜間人口比率は昼間人口 ÷ 夜間人口 × 100 です。原典の第1-1-2表の公表値と一致するので、比率の表は別に持っていません（千代田区は 903,780 ÷ 66,680 × 100 = 1355.39892）。

```sql
-- 昼夜間人口比率の高い市区町村
SELECT
    area,
    area_name,
    MAX(value) FILTER (WHERE location_code = '0') AS nighttime_population,
    MAX(value) FILTER (WHERE location_code = '1') AS daytime_population,
    ROUND(
        MAX(value) FILTER (WHERE location_code = '1') * 100.0
        / MAX(value) FILTER (WHERE location_code = '0'), 1
    ) AS daytime_ratio
FROM e_stat.census.census_municipality_daytime_population
WHERE sex_code = '0' AND area_level IN ('city', 'town_village')
GROUP BY area, area_name
ORDER BY daytime_ratio DESC
LIMIT 10
```

## 流出人口・流入人口が指す範囲は粒度で変わる

`0R1`（再掲）流出人口と `1R1`（再掲）流入人口は `location_level` が大区分と同じ 2 ですが、他の区分の一部を足し直した再掲なので、一緒に合計すると二重に数えます。`is_reprint` で分けてあります。

どこまでを地域の外とみなすかは `area_level` で変わります。

| area_level | 流出人口 | 流入人口 |
|-----------|---------|---------|
| ward / town_village / 政令指定都市以外の city | 0031 + 0032 + 0033 | 101（= 1011 + 1012 + 1013） |
| 政令指定都市・特別区部 | 0032 + 0033 | 1012 + 1013 |
| prefecture | 0033 | 1013 |
| national | NULL | NULL |

粒度によらず成り立つのは次の恒等式で、全1,965地域・男女3区分で確認しています。

```
昼間人口 = 夜間人口 − 流出人口 + 流入人口
```

## 通勤・通学の行き先

`census_commuting_flow` は1行が「常住地 → 従業地・通学地」1組にあたる OD（起終点）行列です。従業地・通学地は都道府県までで、市区町村どうしの流動は含みません。

`destination_area_level` は `total`（総数1区分）・`prefecture`（都道府県47区分）・`unknown`（従業・通学市区町村「不詳・外国」`99998` と従業地・通学地「不詳」`99999`）の3つです。`total` の値は `prefecture` と `unknown` の和に等しいので、絞らずに合計すると2倍になります。

```sql
-- 東京都へ通勤・通学する人が多い都外の市区町村
SELECT area, area_name, value AS commuters_to_tokyo
FROM e_stat.census.census_commuting_flow
WHERE destination_area = '13000'
  AND sex_code = '0'
  AND area_level IN ('city', 'town_village')
  AND area NOT LIKE '13%'
ORDER BY value DESC NULLS LAST
LIMIT 10
```

常住地と同じ都道府県のセルには、自市区町村内で従業・通学する人（自宅外）も入ります。「県外へ出る人」を数えるには、`destination_area` が常住地の都道府県コードと違う行だけを取ります。

```sql
-- 県外で従業・通学する人の割合（市区町村）
SELECT
    area,
    area_name,
    SUM(value) FILTER (WHERE destination_area <> LEFT(area, 2) || '000'
                         AND destination_area_level = 'prefecture')
        / MAX(value) FILTER (WHERE destination_area_level = 'total') AS outbound_share
FROM e_stat.census.census_commuting_flow
WHERE sex_code = '0' AND area_level IN ('city', 'town_village')
GROUP BY area, area_name
ORDER BY outbound_share DESC
LIMIT 10
```

## 2つのテーブルをつなぐ

`census_commuting_flow` が数えているのは自宅外で従業・通学する人だけで、自宅で従業する人（`0021`）と従業も通学もしていない人（`001`）は含みません。母集団は次の関係でつながります（全1,965地域・男女3区分で成立）。

```
flow の総数 − flow の従業地・通学地「不詳」（99999）
  = daytime の 自宅外の自市区町村で従業・通学（0022） + 他市区町村で従業・通学（003）
flow の従業・通学市区町村「不詳・外国」（99998） = daytime の同区分（0034）
```

## 収録の範囲と欠測

年齢は総数のみです。年齢階級別（5歳階級）の従業地・通学地は原典にはありますが、このテーブルには含みません。従業地・通学地の市区町村どうしの流動も原典にはありますが、含みません。

原典が「-」の区分は NULL です。`census_municipality_daytime_population` は112,005行のうち11,360行、`census_commuting_flow` は294,750行のうち175,672行が NULL で、いずれも該当者がいない（0人）ことを表します。

## 他のテーブルとつなぐ

`area` は標準地域コード（5桁）です。`census_municipality` の `area`、`code.municipality` の `area_code`、`census_small_area_*` の市区町村行、`boundary.small_area` の `key_code` の上位5桁と同じ体系です。

```sql
-- 人口10万人以上の市区町村で、昼夜間人口比率の高い順
SELECT
    m.area_name,
    m.population,
    d.daytime_ratio
FROM e_stat.census.census_municipality m
JOIN (
    SELECT
        area,
        MAX(value) FILTER (WHERE location_code = '1') * 100.0
            / MAX(value) FILTER (WHERE location_code = '0') AS daytime_ratio
    FROM e_stat.census.census_municipality_daytime_population
    WHERE sex_code = '0'
    GROUP BY area
) d USING (area)
WHERE m.area_level IN ('city', 'town_village') AND m.population >= 100000
ORDER BY d.daytime_ratio DESC
LIMIT 10
```

市区町村より細かい粒度で昼間人口を見たいときは[1kmメッシュ別 昼間人口](/cookbook/e_stat/mesh-daytime)を使います。そちらは按分による推計値で、公的統計として昼間人口が公表されているのはこのテーブルの市区町村までです。

`lg_code` や `address_br` が使う全国地方公共団体コードは6桁で、末尾にチェックデジットが付く別の体系です。結合するときは桁と体系を揃えてください。
