---
title: 調査品目の年平均価格
order: 23
---

# 小売物価統計調査 調査品目の年平均価格（item_price）

同じ品物が市によっていくらで売られているかを、指数ではなく円のまま収録します。テーブルは `e_stat.retail_price.item_price`。2000年から2025年までの1,207,312行です。

出典: [総務省統計局 小売物価統計調査（動向編） 調査品目の年平均価格](https://www.e-stat.go.jp/stat-search/database?statdisp_id=0003420453)

## カラム構成

- cat02 / item_name: 品目コード / 品目名（`01021` = `1021 食パン`）
- item_note: 品目名の末尾に付く【…】の注記。注記が無ければ NULL
- area / area_name: 地域コード / 市名（`13100` = `特別区部`）
- area_note: 市名の末尾に付く【…】の注記。そのコードが有効な期間が入る
- time / time_name: 時間軸。年次だけで `2024年` の形式
- year: 年
- unit: 単位
- value: 年平均価格

地域は都道府県庁所在市及び人口15万以上の市で、1年に載るのは71〜81市です。47都道府県すべてに1市以上ありますが、全国計の行はありません。

## 品目を探す

```sql
SELECT DISTINCT cat02, item_name
FROM e_stat.retail_price.item_price
WHERE item_name LIKE '%コーヒー%'
ORDER BY cat02
```

## 同じ品目の市別価格

食パン（`01021`）の2024年の価格を高い順に並べます。2024年は那覇市の718円が最も高く、函館市の304円が最も安い値です。

```sql
SELECT area_name, value
FROM e_stat.retail_price.item_price
WHERE cat02 = '01021' AND year = 2024 AND value IS NOT NULL
ORDER BY value DESC
```

## ある市の価格の推移

```sql
SELECT year, value
FROM e_stat.retail_price.item_price
WHERE cat02 = '01021' AND area = '13100'
ORDER BY year
```

## 都道府県を付けて見る

`area` は5桁の標準地域コードそのものなので、`code.municipality` と直接つなげます。

```sql
SELECT m.pref_name, p.area_name, p.value
FROM e_stat.retail_price.item_price p
JOIN e_stat.code.municipality m ON m.area_code = p.area
WHERE p.cat02 = '01021' AND p.year = 2024 AND p.value IS NOT NULL
ORDER BY p.value DESC
```

## 品目をまたいで価格を比べない

価格は品目ごとに決められた数量（1kg当たり・100g当たりなど）に対する額ですが、その数量はこの表に入っていません。`value` を品目間で並べても意味を持ちません。比べられるのは同じ品目の市どうしか、同じ品目・同じ市の年どうしです。数量の規格は[統計局の調査品目及び基本銘柄](https://www.stat.go.jp/data/kouri/doukou/3.html#meigara)にあります。

## 単位が円でない品目がある

`unit` は全行「円」ですが、火災・地震保険料の5品目（`03182`〜`03184`, `03186`, `03187`）は保険料率で、実際の単位は割合です。見分けられるのは `item_note` の【表章単位：割合】だけです。`value` が 0 の行（公立高校授業料や保育料の無償化）と、負の行（電気代の燃料費調整単価）もあります。

## その年に調査していない組合せは NULL

市と品目の組合せの22%は `value` が NULL です。調査を終えた品目も掲載を終えた市も行としては残るので、その年に実際に値がある組合せだけが必要なら `value IS NOT NULL` で絞ります。

## 市のコードは政令指定都市への移行で変わる

`code.municipality` とつながるのは95コード中88件です。つながらない7件は政令指定都市になる前のコードで、`area_note` に有効期間が入ります。

```
浦和市 11204（〜2001年4月） → さいたま市 11244（2001年5月〜2003年3月） → さいたま市 11100
新潟市 15201（〜2007年3月） → 新潟市 15100
```

市の時系列を通して見るときは、コードではなく市の名称で寄せるか `code.municipality_change` で対応させます。

## cpi.price_index との違い

`cpi.price_index` は地域ごとに2020年 = 100 に揃えた指数なので、市どうしの水準は比べられません。比べられるのは同じ地域の時間変化です。円の水準で市を並べられるのはこの表です。地域コードの体系も違い、`cpi.price_index` は `01A01` 形式、`household.expenditure` は `01003` 形式で、どちらも `area_name` の先頭5桁がこの表の `area` にあたります。

全国統一価格品目（たばこ・郵便料金など）は市別に調査しないのでこの表にはありません。
