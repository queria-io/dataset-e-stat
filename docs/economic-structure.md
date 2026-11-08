---
title: 経済構造実態調査 企業産業別の売上・付加価値、費用内訳、都道府県別の事業所数
order: 47
---

# 経済構造実態調査 企業産業別の売上・付加価値、費用内訳、都道府県別の事業所数

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| enterprise_industry | 全国の企業産業（小分類まで）別・経営組織別の企業等数・売上（収入）金額・費用・付加価値額 | year / industry_code / industry_level / organization_code / measure_code / unit / value |
| cost_composition | 全国の事業区分（中分類、一部は小分類）別の費用内訳割合（％） | year / business_code / cost_item_code / cost_scope / cost_item / share_percent |
| establishment_prefecture | 全国・都道府県別、産業大分類別の事業所数と売上（収入）金額 | year / area / area_level / industry_code / industry_level / establishments / sales_million_yen |

総務省・経済産業省の経済構造実態調査です。毎年6月1日現在の企業等・事業所について、前年1年間の
売上と費用を調べます。2019・2020・2022〜2025年を収録しています。2021年は経済センサス‐活動調査の
年で、この調査はありません。経済センサスの値は `economic_census` スキーマにあります。

対象は会社企業と会社以外の法人で、個人経営を含みません。2019・2020年の調査は農林漁業・鉱業・
建設業を含まないので、enterprise_industry の全産業（`industry_code` = `ER`）はほかの年の
全産業（`AR`）より範囲が狭くなります。

## 産業コード

`industry_code` は日本標準産業分類のコードです。2024年までの表は産業の軸に表内の通し番号を振り、
分類コードを名称の先頭に置いていたので、そのコードに置き換えています。2024年の表から小分類が
いくつか増えています（562 総合スーパーマーケット、563 コンビニエンスストア など）。

全産業・大分類・中分類・小分類が同じ列に並びます。`industry_level` で段を絞ってから合計します。
大分類（`division`）を足すと全産業に一致します（原典の丸めで最大0.1%未満ずれます）。

## 表章項目

enterprise_industry の表章項目は `measure_code` で絞ります。原典の表章項目コードは年で振り直されて
いるので、名前をそろえてあります。支払利息等（`interest_expenses`）は2020年まで、商品売上原価
（`cost_of_goods_sold`）は2022年からしかありません。

```sql
-- 2025年 大分類別の付加価値額
SELECT industry_code, industry_name, value AS value_added_million_yen
FROM e_stat.economic_structure.enterprise_industry
WHERE year = 2025 AND organization_code = '0'
  AND industry_level = 'division' AND measure_code = 'value_added'
ORDER BY value DESC;
```

## 費用内訳

cost_composition は事業区分ごとに、費用総額に占める各費用項目の割合（％）を持ちます。
事業区分ごとに足すと100になります。給与総額や外注費のようにどの事業区分にもある項目は
`cost_scope` が「産業共通」で、燃料費（電気業）や商品売上原価（卸売業、小売業）のように
特定の事業区分だけの項目はその事業区分の名前が入ります。

## 都道府県別の事業所

establishment_prefecture は事業所の所在地で集計した値です。全国の事業所数は都道府県の和に
一致します。売上（収入）金額は全産業と一部の大分類（建設業、電気・ガス・熱供給・水道業、
運輸業，郵便業、金融業，保険業）に値がありません。
