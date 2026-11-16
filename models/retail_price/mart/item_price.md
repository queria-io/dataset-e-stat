---
$schema: https://queria.io/schemas/table/v1.json
table: retail_price.item_price
title: 調査品目の年平均価格（市別）
description: |-
  小売物価統計調査の調査品目の年平均価格（円）を、都道府県庁所在市と人口15万以上の市ごとに2000年から持つテーブルです。

  - 数量規格が品目ごとに違うので、品目をまたいで価格を比べられません
  - その年その市で調査していない組合せは NULL です
keywords:
  - e-stat
  - 小売物価統計調査
  - 小売価格
  - 価格
  - 物価
  - 品目
  - 市区町村
sources:
  - path: https://www.e-stat.go.jp/stat-search/database?statdisp_id=0003420453
fields:
  - name: cat02
    title: 品目コード
    description: 品目コード（5桁）。e-Stat の分類軸「銘柄」で、階層は無く全品目が同じ高さに並ぶ。品目番号は item_name の先頭にも付く。2015年1月・2020年1月の符号変更で同じ品目に新旧2つのコードがあることがあり、item_note に移動先の番号が入る
  - name: item_name
    title: 品目名
    description: cat02 に対応する品目名。「1001 うるち米(単一原料米,「コシヒカリ」)」のように品目番号が前置され、末尾に【…】の注記が付くことがある
  - name: item_note
    title: 品目の注記
    description: item_name の末尾に付く【…】の注記。調査終了年（【2021年12月調査終了】）、符号変更（【2015年01月から3511 電気代】）、表章単位（【表章単位：割合】）などで、注記の無い品目は NULL。現役の品目だけを見るなら調査終了の注記を除く
  - name: area
    title: 地域コード
    description: "地域コード（5桁）。統計に用いる標準地域コードそのものなので soumu.code.municipality と直接つながる（実測: 95コード中88。残る7つは政令指定都市へ移行する前の市のコードで、現行の一覧には無い）。cpi.price_index（01A01 形式）や household.expenditure（01003 形式）とは体系が違い、そちらは area_name の先頭5桁がこのコードにあたる。東京は 13100 特別区部で、特別区をまとめた1行"
    semantic: {role: entity, name: city}
  - name: area_name
    title: 市名
    description: area に対応する市の名称。cpi や household と違いコードは前置されない。末尾に【…】の注記が付くことがある
  - name: area_note
    title: 市の注記
    description: area_name の末尾に付く【…】の注記で、その市のコードが有効な期間。注記の無い市は NULL。政令指定都市への移行や合併で同じ市に複数のコードがある（浦和市 11204 →さいたま市 11244 →さいたま市 11100、新潟市 15201 → 15100 など）ので、市の時系列を通して見るときはコードではなく市の名称で寄せるか、code.municipality_change で対応させる
  - name: time
    title: 時間軸コード
    description: 時間軸コード。年次だけで 2024000000 の形
  - name: time_name
    title: 時間軸名
    description: 時間軸の名称。「2024年」
  - name: year
    title: 年
    description: time から切り出した西暦4桁。2000〜2025で欠けは無い
  - name: unit
    title: 単位
    description: 単位。全行「円」が入るが、火災・地震保険料の5品目だけは実際には保険料率（割合）で、この列では見分けられない。item_note の【表章単位：割合】で判別する。3186・3187 は2024年までが円、2025年から割合
  - name: value
    title: 年平均価格
    description: 年平均価格。その年その市で調査していない品目は NULL（全体の22%）。公立高校授業料や保育料のように無償化で 0 の行、電気代の燃料費調整単価のように負の行もある
themes: [economy]
---

# 小売物価統計調査 調査品目の年平均価格（item_price）

同じ品物が市によっていくらで売られているかを、指数ではなく円のまま収録します。テーブルは `e_stat.retail_price.item_price`。2000年から2025年までの1,207,312行です。

出典: [総務省統計局 小売物価統計調査（動向編） 調査品目の年平均価格](https://www.e-stat.go.jp/stat-search/database?statdisp_id=0003420453)

## 列の使い方

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

`area` は5桁の標準地域コードそのものなので、`soumu.code.municipality` と直接つなげます。

```sql
SELECT m.pref_name, p.area_name, p.value
FROM e_stat.retail_price.item_price p
JOIN soumu.code.municipality m ON m.area_code = p.area
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

`soumu.code.municipality` とつながるのは95コード中88件です。つながらない7件は政令指定都市になる前のコードで、`area_note` に有効期間が入ります。

```
浦和市 11204（〜2001年4月） → さいたま市 11244（2001年5月〜2003年3月） → さいたま市 11100
新潟市 15201（〜2007年3月） → 新潟市 15100
```

市の時系列を通して見るときは、コードではなく市の名称で寄せるか `code.municipality_change` で対応させます。

## cpi.price_index との違い

`cpi.price_index` は地域ごとに2020年 = 100 に揃えた指数なので、市どうしの水準は比べられません。比べられるのは同じ地域の時間変化です。円の水準で市を並べられるのはこの表です。地域コードの体系も違い、`cpi.price_index` は `01A01` 形式、`household.expenditure` は `01003` 形式で、どちらも `area_name` の先頭5桁がこの表の `area` にあたります。

全国統一価格品目（たばこ・郵便料金など）は市別に調査しないのでこの表にはありません。

## 補足: 小売物価統計調査 調査品目の年平均価格（retail_price スキーマ）

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| item_price | 都道府県庁所在市及び人口15万以上の市の品目別年平均価格 | cat02 / item_name / item_note / area / area_name / year / unit / value |

地域は延べ95コードで、1年に載るのは71〜81市です。47都道府県すべてに1市以上ありますが、
全国計の行はありません。品目は延べ872銘柄で、1年に載るのは534〜693です。市と品目の
組合せの22%は `value` が NULL で、その年その市で調査していないことを表します。

#### 単位が円でない品目がある

`unit` は全行「円」ですが、火災・地震保険料の5品目（3182〜3184, 3186, 3187）は保険料率で、
実際の単位は割合です。見分けられるのは `item_note` の【表章単位：割合】だけです。3186・3187
は2024年までが円、2025年から割合なので、同じ品目コードで単位が切り替わります。

#### 調査を終えた品目と市が同じ列に残る

品目名と市名の末尾には【2021年12月調査終了】【2015年01月から3511 電気代】のような注記が
付きます。`item_note` / `area_note` がその注記で、注記の無い行は NULL です。現役の品目だけを
見るときは調査終了の注記を除きます。

## 補足: retail_price.item_price

品目ごとの小売価格を「円」そのもので市別に収録する。
cpi.price_index が地域ごとに2020年=100 に揃えた指数で水準を比べられないのに対して、こちらは同じ年の市どうしを金額のまま比べられる。
収録は2000年〜2025年の26年、1,207,312行。
品目ごとの数量規格（1kg当たり・100g当たりなど）はこの表に入っていないので、品目をまたいで価格を比べることはできない。
全国統一価格品目（たばこ・郵便料金など）は市別の調査をしないのでこの表に無く、別の統計表に載る。
