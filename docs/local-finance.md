---
title: 決算収支と財政力（地方財政状況調査）
order: 22
---

# 地方財政状況調査 決算収支と財政力（local_finance スキーマ）

都道府県・市区町村がその年度にいくら入れていくら出したか、地方交付税の算定でどれだけの財政力があると見られているかの表です。全団体が報告する全数調査で、標本ではありません。いわゆる「決算カード」の原資料にあたります。

| テーブル | 内容 | 区分の列 | 主な値 |
|---------|------|---------|-------|
| settlement_balance | 都道府県・市区町村・一部事務組合の決算収支 | fiscal_year / survey_scope / entity_kind / area_code | revenue_total / expenditure_total / real_balance / real_single_year_balance |
| fiscal_capacity | 市区町村の財政力指数と標準財政規模 | fiscal_year / area_code | fiscal_capacity_index / standard_fiscal_scale / standard_revenue / standard_demand |

`settlement_balance` は1989年度から2024年度までの156,892行、`fiscal_capacity` は2014年度から2024年度までの19,151行です。金額の単位はすべて千円です。

出典: [地方財政状況調査](https://www.e-stat.go.jp/stat-search/files?toukei=00200251)（総務省）

## 一部事務組合を混ぜたまま合計しない

市町村分の調査表には、市区町村（2024年度で1,741）のほかに一部事務組合と広域連合（同1,321）の行が入ります。市区町村が組合に出す負担金は市区町村の歳出にも組合の歳入にも立つので、絞らずに合計すると二重に数えます。

| entity_kind | 内容 | 2024年度の団体数 |
|---|---|---|
| prefecture | 都道府県 | 47 |
| municipality | 市区町村 | 1,741 |
| association | 一部事務組合・広域連合 | 1,321 |
| total | その調査表の「合計(全国)」 | 2（調査表ごとに1本） |

`total` の行はその調査表に載る全団体の単純な合計です。市町村分の合計は組合を含むので市区町村の合計ではありません（2024年度の市町村分の合計は73.6兆円、市区町村だけの和は71.4兆円）。

```sql
-- 歳出総額の多い市区町村（2024年度）
SELECT entity_name, pref_name, expenditure_total, real_balance
FROM e_stat.local_finance.settlement_balance
WHERE fiscal_year = 2024 AND entity_kind = 'municipality'
ORDER BY expenditure_total DESC
LIMIT 10;
```

## 他のテーブルと結合する

`area_code` は5桁の標準地域コードで、`code.municipality` や census 系の `area` と同じ体系です。6桁の全国地方公共団体コードは `lg_code` に別に入っています。一部事務組合は市区町村ではないので、`area_code` で `code.municipality` を引いても当たりません。

```sql
-- 財政力の弱い市区町村の決算規模（2024年度）。2つの表は area_code で結合する
SELECT c.entity_name, c.pref_name, c.fiscal_capacity_index,
    s.expenditure_total, s.real_balance
FROM e_stat.local_finance.fiscal_capacity c
JOIN e_stat.local_finance.settlement_balance s
    USING (fiscal_year, area_code)
WHERE c.fiscal_year = 2024 AND s.entity_kind = 'municipality'
ORDER BY c.fiscal_capacity_index
LIMIT 10;
```

## 収支の恒等式

- 歳入歳出差引 = 歳入総額 - 歳出総額
- 実質収支 = 歳入歳出差引 - 翌年度に繰り越すべき財源
- 実質単年度収支 = 単年度収支 + 積立金 + 繰上償還金 - 積立金取崩し額

原典の側で合わない行が156,892行中7行あります（2012年度の世田谷区、2023年度の諏訪広域公立大学事務組合と宇和島地区広域事務組合、2024年度の川南町と、それぞれを含む合計の行3本）。原典の値をそのまま収録しています。

## 団体の数は年度で変わる

市区町村の行数は1989年度の3,268から2024年度の1,741まで減ります。平成の大合併で市町村そのものが減ったためで、収録の欠けではありません。年度をまたいで同じ団体を追うときは、`code.municipality_change` の廃置分合履歴で読み替えます。

## 財政力指数は市区町村だけ・2014年度から

`fiscal_capacity` は調査表の表紙から取っています。列に名前が付くのは市町村分の2014年度決算以降で、それ以前は「列001」…という無名の90列になり、同じ位置が年度によって別の項目を指します（2005年度決算の列009は財政力指数、2009年度決算の列009は臨時財政対策債発行可能額）。位置から当てにいくと黙って別の値が入るので取っていません。都道府県の表紙は財政力の列を持たないため、この表は市区町村だけです。

一部事務組合と広域連合は地方交付税の算定対象ではなく、原典でも全項目が0で入るので落としています。`code.municipality` が市区町村として数える1,747件のうち、北方領土の6村は調査の対象外で行がありません。

`fiscal_capacity_index` は基準財政収入額を基準財政需要額で割った値の3か年平均で、小数第2位までです（2024年度で1を超えるのは1,741市区町村のうち74）。3か年平均なので、普通交付税の交付・不交付を単年度で判定した結果とは一致しません。

```sql
-- 財政力指数の高い市区町村（2024年度）
SELECT entity_name, pref_name, fiscal_capacity_index, standard_fiscal_scale
FROM e_stat.local_finance.fiscal_capacity
WHERE fiscal_year = 2024
ORDER BY fiscal_capacity_index DESC
LIMIT 10;
```
