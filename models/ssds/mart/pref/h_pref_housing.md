# H 居住

総住宅数、持ち家、住宅の種類など、居住に関する指標を収録します。

- 都道府県: `e_stat.ssds.h_pref_housing`
- 市区町村: `e_stat.ssds.h_municipal_housing`（廃置分合処理済）

項目定義: [社会・人口統計体系 H](https://www.e-stat.go.jp/koumoku/koumoku_teigi/H)

## 代表的な指標

| cat01 | 指標 |
|-------|------|
| H1100 | 総住宅数 |
| H1101 | 居住世帯あり住宅数 |
| H1310 | 持ち家数 |

## 都道府県別の総住宅数ランキング（最新年）

```sql
SELECT area_name, MAX(value) AS dwellings
FROM e_stat.ssds.h_pref_housing
WHERE cat01 = 'H1100'
  AND area_name <> '全国'
  AND year = (SELECT MAX(year) FROM e_stat.ssds.h_pref_housing WHERE cat01 = 'H1100')
GROUP BY area_name
ORDER BY dwellings DESC
LIMIT 10
```

## 全国の総住宅数の推移

```sql
SELECT year, MAX(value) AS dwellings
FROM e_stat.ssds.h_pref_housing
WHERE cat01 = 'H1100' AND area_name = '全国'
GROUP BY year
ORDER BY year
```
