# D 行政基盤

地方公共団体の職員数や財政に関する指標を収録します。

- 都道府県: `e_stat.ssds.d_pref_administration`
- 市区町村: `e_stat.ssds.d_municipal_administration`（廃置分合処理済）

項目定義: [社会・人口統計体系 D](https://www.e-stat.go.jp/koumoku/koumoku_teigi/D)

## 代表的な指標

| cat01 | 指標 |
|-------|------|
| D1201 | 一般行政部門職員数（都道府県） |
| D1203 | 消防部門職員数 |
| D1204 | 教育部門職員数 |
| D1205 | 警察部門職員数 |

## 都道府県別の一般行政部門職員数ランキング（最新年）

```sql
SELECT area_name, MAX(value) AS staff
FROM e_stat.ssds.d_pref_administration
WHERE cat01 = 'D1201'
  AND area_name <> '全国'
  AND year = (SELECT MAX(year) FROM e_stat.ssds.d_pref_administration WHERE cat01 = 'D1201')
GROUP BY area_name
ORDER BY staff DESC
LIMIT 10
```

## 全国の一般行政部門職員数の推移

```sql
SELECT year, MAX(value) AS staff
FROM e_stat.ssds.d_pref_administration
WHERE cat01 = 'D1201' AND area_name = '全国'
GROUP BY year
ORDER BY year
```
