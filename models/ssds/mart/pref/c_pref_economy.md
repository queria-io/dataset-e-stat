# C 経済基盤

県内総生産、事業所数、課税対象所得など、地域の経済活動に関する指標を収録します。

- 都道府県: `e_stat.ssds.c_pref_economy`
- 市区町村: `e_stat.ssds.c_municipal_economy`（廃置分合処理済）

項目定義: [社会・人口統計体系 C](https://www.e-stat.go.jp/koumoku/koumoku_teigi/C)

## 代表的な指標

| cat01 | 指標 |
|-------|------|
| C120110 | 課税対象所得 |
| C1127 | 県内総生産額（第３次産業）（平成27年基準） |
| C210847 | 事業所数（民営）（宿泊業、飲食サービス業） |

産業別・基準年別に多数の指標があるため、`item_catalog`（`table_title = 'Ｃ　経済基盤'`）での検索が有効です。

## 都道府県別の課税対象所得ランキング（最新年）

```sql
SELECT area_name, MAX(value) AS taxable_income
FROM e_stat.ssds.c_pref_economy
WHERE cat01 = 'C120110'
  AND area_name <> '全国'
  AND year = (SELECT MAX(year) FROM e_stat.ssds.c_pref_economy WHERE cat01 = 'C120110')
GROUP BY area_name
ORDER BY taxable_income DESC
LIMIT 10
```

## 全国の課税対象所得の推移

```sql
SELECT year, MAX(value) AS taxable_income
FROM e_stat.ssds.c_pref_economy
WHERE cat01 = 'C120110' AND area_name = '全国'
GROUP BY year
ORDER BY year
```
