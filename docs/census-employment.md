---
title: 就業状態等基本集計（国勢調査）
order: 16
---

# 令和2年国勢調査 就業状態等基本集計（census スキーマ）

市区町村・都道府県の単位で、働いているかどうか（労働力状態）と、働き方（従業上の地位）を持つ2つのテーブルです。[市区町村別 基本集計](/cookbook/e_stat/census-municipality)が人口と世帯を扱うのに対し、こちらは就業の側面を扱います。働く場所・通う場所の側から見るときは[昼夜間人口と通勤・通学流動](/cookbook/e_stat/census-commuting)を使います。地域を並べて労働力率や非正規雇用の割合を比べたいときに使います。

| テーブル | 内容 | 区分の列 | 値 |
|---------|------|---------|----|
| census_municipality_labor_force | 男女・労働力状態別 15歳以上人口 | labor_status_code / labor_status | 人口 |
| census_municipality_employment_status | 男女・従業上の地位別 就業者数 | employment_status_code / employment_status | 就業者数 |

どちらも縦持ちで、1地域あたり `census_municipality_labor_force` が 39行（男女3 × 労働力状態13）、`census_municipality_employment_status` が 36行（男女3 × 従業上の地位12）です。年齢は総数のみで、年齢階級別の内訳は含みません。

出典: [令和2年国勢調査 就業状態等基本集計](https://www.e-stat.go.jp/statistics/00200521)（第1-2-1表・第3-2表）

## 粒度を混ぜると二重に数える

`area` は [市区町村別 基本集計](/cookbook/e_stat/census-municipality) と同じ標準地域コード（5桁）で、そこから2000年（平成12年）市区町村の再掲を除いた1,965地域です。粒度は `area_level` で判別します。

| area_level | 内容 | 地域数 | 15歳以上人口の合計 |
|-----------|------|-------:|------------------:|
| national | 全国 | 1 | 108,258,569 |
| prefecture | 都道府県 | 47 | 108,258,569 |
| city | 市・特別区部 | 793 | 99,161,646 |
| town_village | 町村 | 926 | 9,096,923 |
| ward | 政令指定都市の区・特別区 | 198 | 31,968,922 |

日本全域をちょうど1回覆うのは `prefecture` だけ、または `city` と `town_village` の組だけです。東京23区が `city` ではなく `ward` に入る点も基本集計と同じで、`city` に入るのは23区をまとめた「特別区部」（`13100`）1行です。

## 総数・大区分・内訳が同じ列に並ぶ

区分の列には総数もその内訳も縦に並びます。深さは `labor_status_level` / `employment_status_level` に出ています。

| labor_status_code | labor_status | level |
|------------------|-------------|------:|
| 0 | 総数 | 1 |
| 1 | 労働力人口 | 1 |
| 11 | 就業者 | 2 |
| 111 / 112 / 113 / 114 | 主に仕事 / 家事のほか仕事 / 通学のかたわら仕事 / 休業者 | 3 |
| 12 | 完全失業者 | 2 |
| 2 | 非労働力人口 | 1 |
| 21 / 22 / 23 | 家事 / 通学 / その他 | 2 |
| 3 | 労働力状態「不詳」 | 1 |

合計に使えるのは `labor_status_level = 1` かつ `labor_status_code <> '0'` の3行（労働力人口・非労働力人口・労働力状態「不詳」）で、その和が総数に一致します。男女（`sex_code`）も総数・男・女が同じ列に並ぶので、併せて絞ります。

```sql
-- 市区町村別の労働力率（労働力人口 ÷ 15歳以上人口）
SELECT
    area_name,
    MAX(value) FILTER (WHERE labor_status_code = '1')
        / MAX(value) FILTER (WHERE labor_status_code = '0') AS labor_force_rate
FROM e_stat.census.census_municipality_labor_force
WHERE sex_code = '0' AND area_level IN ('city', 'town_village')
GROUP BY area, area_name
ORDER BY labor_force_rate DESC
LIMIT 10
```

## 従業上の地位には再掲がある

`census_municipality_employment_status` の区分は総数・大区分（雇用者・役員・業主・家族従業者・家庭内職者・不詳）と、雇用者の内訳（正規の職員・従業員／派遣社員／パート・アルバイト・その他）です。

これに加えて「（再掲）雇用者（役員を含む）」（`R1`）があります。level は大区分と同じ 1 ですが、雇用者と役員を足し直した再掲なので、一緒に合計すると二重に数えます。`is_reprint` で分けてあるので、合計するときは `employment_status_level = 1 AND employment_status_code <> '0' AND NOT is_reprint` の7行を使います。

```sql
-- 市区町村別の非正規雇用の割合（派遣社員 + パート・アルバイト ÷ 雇用者）
SELECT
    area,
    area_name,
    SUM(value) FILTER (WHERE employment_status_code IN ('12', '13'))
        / SUM(value) FILTER (WHERE employment_status_code = '1') AS nonregular_share
FROM e_stat.census.census_municipality_employment_status
WHERE sex_code = '0' AND area_level IN ('city', 'town_village')
GROUP BY area, area_name
ORDER BY nonregular_share DESC
LIMIT 10
```

同じ地域名の市町村が複数の県にあります（川上村は長野県と奈良県、東村は沖縄県）。並べるときは `area` も一緒に出してください。

## 2つのテーブルをつなぐ

`census_municipality_employment_status` の総数（`employment_status_code = '0'`）は、`census_municipality_labor_force` の就業者（`labor_status_code = '11'`）と全行で一致します。働き方の内訳を労働力状態の側から見るときは、この2つで結合します。

```sql
-- 男女別の正規雇用比率（都道府県）
SELECT
    e.area_name,
    e.sex,
    SUM(e.value) FILTER (WHERE e.employment_status_code = '11')
        / SUM(e.value) FILTER (WHERE e.employment_status_code = '0') AS regular_share
FROM e_stat.census.census_municipality_employment_status e
WHERE e.area_level = 'prefecture' AND e.sex_code IN ('1', '2')
GROUP BY e.area_name, e.sex
ORDER BY e.area_name, e.sex
```

## 収録の範囲と欠測

年齢は総数のみです。年齢階級別（5歳階級）の労働力状態は原典にはありますが、このテーブルには含みません。

`census_municipality_labor_force` の総数（`labor_status_code = '0'`）は年齢が判明した15歳以上人口で、全国で 108,258,569 です。`census_municipality` の `population`（全国 126,146,099）との差 17,887,530 には15歳未満と年齢「不詳」が含まれます。就業に関する比率の分母には、`population` ではなくこのテーブルの総数を使ってください。

原典が「-」の区分は NULL です。内訳の合計が総数と一致することから、「-」は該当者がいない（0人）ことを表します。全町避難が続いた双葉町だけは全行が「-」で、全項目が NULL になります。

## 他のテーブルとつなぐ

`area` は標準地域コード（5桁）です。`census_municipality` の `area`、`code.municipality` の `area_code`、`census_small_area_*` の市区町村行、`boundary.small_area` の `key_code` の上位5桁と同じ体系です。

```sql
-- 人口10万人以上の市区町村で、完全失業率の高い順
SELECT
    m.area_name,
    m.population,
    l.unemployment_rate
FROM e_stat.census.census_municipality m
JOIN (
    SELECT
        area,
        MAX(value) FILTER (WHERE labor_status_code = '12')
            / MAX(value) FILTER (WHERE labor_status_code = '1') AS unemployment_rate
    FROM e_stat.census.census_municipality_labor_force
    WHERE sex_code = '0'
    GROUP BY area
) l USING (area)
WHERE m.area_level IN ('city', 'town_village') AND m.population >= 100000
ORDER BY l.unemployment_rate DESC
LIMIT 10
```

産業別の就業者数は市区町村の粒度でも[小地域集計](/cookbook/e_stat/census)の `census_small_area_industry` にあります（`area_level = 'municipality'`）。ただしそちらは政令指定都市を区の単位で持つので、市全体の行はありません。

`lg_code` や `address_br` が使う全国地方公共団体コードは6桁で、末尾にチェックデジットが付く別の体系です。結合するときは桁と体系を揃えてください。
