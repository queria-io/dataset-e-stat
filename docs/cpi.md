---
title: 消費者物価指数（CPI）
order: 12
---

# 消費者物価指数（price_index）

消費者物価指数（2020年基準）です。品目別の価格指数を全国・地域・都市階級別に月次／年次で収録します。テーブルは `e_stat.cpi.price_index`。

出典: [総務省統計局 消費者物価指数（2020年基準）](https://www.e-stat.go.jp/stat-search/database?statdisp_id=0003427113)

## カラム構成

- tab / tab_name: 表章項目（`1` = 指数、ほかに前月比・前年比など）
- cat01 / item_name: 品目コード / 品目名（`0001` = 総合）
- area / area_name: 地域コード / 地域名（`全国` など67区分）
- time / time_name: 時間軸。年次は `2024年`、月次は `2024年1月` の形式
- year: 年
- unit: 単位
- value: 指数（2020年 = 100）

年次データだけを取りたいときは `time_name LIKE '____年'`、月次は `time_name LIKE '%月'` で絞り込みます。

## 全国・総合指数の年次推移

```sql
SELECT year, value
FROM e_stat.cpi.price_index
WHERE tab = '1' AND cat01 = '0001' AND area_name = '全国'
  AND time_name LIKE '____年'
ORDER BY year
```

## 品目を探す

```sql
SELECT DISTINCT cat01, item_name
FROM e_stat.cpi.price_index
WHERE item_name LIKE '%米%'
ORDER BY cat01
LIMIT 20
```

## 特定品目の月次推移（直近）

米類（`0004`）の直近12か月の指数を取り出します。

```sql
SELECT time_name, value
FROM e_stat.cpi.price_index
WHERE tab = '1' AND cat01 = '0004' AND area_name = '全国'
  AND time_name LIKE '%月'
ORDER BY time DESC
LIMIT 12
```

## 補足: cpi.price_index

品目別価格指数を全国・地域・都市階級別の月次／年次で収録。
指数は地域ごとに 2020年 = 100 に揃えてあるため、地域間で水準を比べても意味を持たない。
比較できるのは同じ地域の時間変化か、tab=2/3 の変化率。
表章（tab）は「指数」「前月比・前年比・前年度比」「前年同月比」の3種類を含む。
品目（cat01）は総合・10大費目から個別品目までの790区分。
地域（area）は全国・都市階級・地方・都道府県庁所在市など67区分。
