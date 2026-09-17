---
title: 市区町村別 転入・転出（住民基本台帳人口移動報告）
order: 21
---

# 住民基本台帳人口移動報告 市区町村別の転入・転出（migration スキーマ）

市区町村ごとに、何人が入ってきて何人が出ていったかを毎年数えた表です。住民票の異動届にもとづく実績なので、将来推計人口と違って推計値ではありません。テーブルは `e_stat.migration.municipality_migration`。

| テーブル | 内容 | 区分の列 | 主な値 |
|---------|------|---------|-------|
| municipality_migration | 全国・都道府県・市区町村・区別の転入者数・転出者数・転入超過数 | area / year / sex_code / nationality_code | inflow / outflow / net_inflow |

2010年から2025年までの210,927行です。市区町村をまたぐ移動だけを数えるので、同一市区町村内の引っ越しと国外との出入りは入りません。全国の転入超過数は、どの移動も転入と転出の両方に数えられるため定義上 0 になります。

出典: [住民基本台帳人口移動報告](https://www.stat.go.jp/data/idou/) 年報（[2020年以降](https://www.e-stat.go.jp/dbview?sid=0003419945) / [2019年以前](https://www.e-stat.go.jp/dbview?sid=0003461887)）

## カラム構成

- area / area_name: 標準地域コード（5桁） / 地域名
- area_level: 地域の粒度（`national` / `prefecture` / `municipality` / `ward` / `county` / `urban_rural_part`）
- parent_area: 1つ上の階層の地域コード
- year: 年（1月から12月までの移動を積んだ年次）
- sex_code / sex: 性別（`0` = 総数、`1` = 男、`2` = 女）
- nationality_code / nationality: 国籍区分（`60000` = 移動者、`61000` = 日本人移動者、`62000` = 外国人移動者）
- inflow / outflow / net_inflow: 転入者数 / 転出者数 / 転入超過数（人）

`net_inflow` は `inflow - outflow` に等しく、負の値は転出超過を表します。

## 地域の粒度を必ず絞る

area には市区町村のほかに集計行が縦に並びます。`area_level` を絞らずに合計すると何重にも数えます。

| area_level | 内容 | 地域数 |
|---|---|---|
| national | 全国 | 1 |
| prefecture | 都道府県 | 47 |
| municipality | 市・町村・政令指定都市・東京都特別区部 | 1,736 |
| ward | 政令指定都市の区・特別区 | 201 |
| county | 郡・北海道の振興局・東京の支庁 | 332 |
| urban_rural_part | 市部・郡部 | 96 |

日本全域をちょうど1回覆うのは `municipality` だけです。`ward` はその内訳（千代田区は東京都特別区部の内訳、中央区は札幌市の内訳）、`county` は町村の合計、`urban_rural_part` は市と町村を別の切り方でまとめた合計です。

地域数は年によって変わります。2025年は `county` と `urban_rural_part` の行がありません。市区町村と区を合わせた行がある地域は2025年で1,913です。

## 国籍区分で収録の始まる年が違う

| nationality_code | 区分 | 収録 |
|---|---|---|
| 61000 | 日本人移動者 | 2010年〜 |
| 60000 | 移動者（日本人と外国人の合計） | 2018年〜 |
| 62000 | 外国人移動者 | 2020年〜 |

2017年以前まで遡る時系列は `61000` で引きます。`60000` で引くと2018年から始まる系列になり、2017年と2018年の間に外国人の分だけ段差ができます。

## 転入超過の多い市区町村

```sql
SELECT area_name, inflow, outflow, net_inflow
FROM e_stat.migration.municipality_migration
WHERE year = 2025 AND area_level = 'municipality'
  AND sex_code = '0' AND nationality_code = '60000'
ORDER BY net_inflow DESC
LIMIT 10
```

`ORDER BY net_inflow` に変えると転出超過の多い順になります。

## 1つの市区町村の推移

新宿区（`13104`）を2010年から引きます。日本人移動者で引くと16年分そろいます。

```sql
SELECT year, inflow, outflow, net_inflow
FROM e_stat.migration.municipality_migration
WHERE area = '13104' AND sex_code = '0' AND nationality_code = '61000'
ORDER BY year
```

## 転入超過が続いている市区町村

2020年から2025年まで一度も転出超過にならなかった市区町村です。

```sql
SELECT area_name, SUM(net_inflow) AS total
FROM e_stat.migration.municipality_migration
WHERE year >= 2020 AND area_level = 'municipality'
  AND sex_code = '0' AND nationality_code = '60000'
GROUP BY area, area_name
HAVING MIN(net_inflow) > 0
ORDER BY total DESC
LIMIT 10
```

## 日本人と外国人を分けて見る

```sql
SELECT area_name,
    MAX(net_inflow) FILTER (WHERE nationality_code = '61000') AS japanese,
    MAX(net_inflow) FILTER (WHERE nationality_code = '62000') AS foreign_national
FROM e_stat.migration.municipality_migration
WHERE year = 2025 AND area_level = 'prefecture' AND sex_code = '0'
GROUP BY area_name
ORDER BY japanese DESC
LIMIT 10
```

国外との出入りは入らないので、ここに出るのは国内で都道府県をまたいだ移動だけです。

## 人口と並べる

area は `code.municipality` の `area_code` や census 系の `area` と同じ標準地域コード（5桁）です。`census.census_municipality` と結合すると人口あたりの転入超過を出せます。全国地方公共団体コード（6桁）とは別体系なので、`lg_code` と結合するときは桁を揃えます。

```sql
SELECT m.area_name, c.population, m.net_inflow,
    ROUND(m.net_inflow * 1000.0 / c.population, 2) AS net_per_1k
FROM e_stat.migration.municipality_migration m
JOIN e_stat.census.census_municipality c ON c.area = m.area
WHERE m.year = 2025 AND m.area_level = 'municipality'
  AND m.sex_code = '0' AND m.nationality_code = '60000'
  AND c.population > 50000
ORDER BY net_per_1k DESC
LIMIT 10
```

## resident_registry.population の転入・転出との違い

同じ住民票の異動から作られる数が `resident_registry.population` にもあります（`moved_in_domestic` / `moved_out_domestic`）。対象期間は2014年以降どちらも暦年で同じですが（住基のほうは調査期日1月1日の直前1年間なので、`year = 2026` の行が2025年にあたります）、別々に集計された統計なので値は一致しません。2025年の全国・日本人の国内転入は、この表が4,528,254人、住基の動態が4,523,542人です。

全国で転入と転出が一致するのはこの表だけです。住基の動態は同じ2025年の全国・日本人で国内転入4,523,542人・国内転出4,544,769人と差が残ります。転入超過を見るならこの表、国外との出入りや出生・死亡まで含めて人口の増減を追うなら `resident_registry.population` を使い、系列は片方で通します。

## 年齢階級の内訳は持っていない

原典には年齢別の表もありますが、年齢区分が年代で違います（2019年以前は3区分、2020年以降は5歳階級）。同じ列に積むと区分の意味が年で変わるため、この表は年齢の総数だけを収録しています。

## 欠測値

原典が欠測値としている市区町村と年があります。転出者数が入らないのは矢祭町（`07482`）の2010年〜2014年と国立市（`13215`）の2010年〜2011年、転入超過数が入らないのはその翌年まで（矢祭町は2015年、国立市は2012年）です。転入者数はどの年もあります。都道府県と全国の値もその分を欠いたまま積まれているので、市区町村の和は都道府県の値と一致します。

政令指定都市に移行した年だけは、市の値が通年で区の値が4月以降になるため、区の和が市に届きません（相模原市の2010年・熊本市の2012年）。
