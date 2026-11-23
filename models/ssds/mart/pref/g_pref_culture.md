# G 文化・スポーツ

公民館・図書館などの社会教育施設、社会教育・社会体育の職員数など、文化・スポーツに関する指標を収録します。

- 都道府県: `e_stat.ssds.g_pref_culture`
- 市区町村: `e_stat.ssds.g_municipal_culture`（廃置分合処理済）

項目定義: [社会・人口統計体系 G](https://www.e-stat.go.jp/koumoku/koumoku_teigi/G)

## 代表的な指標

| cat01 | 指標 |
|-------|------|
| G1201 | 公民館数 |
| G1101 | 社会教育関係職員数 |
| G1103 | 社会教育主事数 |

## 都道府県別の公民館数ランキング（最新年）

```sql
SELECT area_name, MAX(value) AS community_centers
FROM e_stat.ssds.g_pref_culture
WHERE cat01 = 'G1201'
  AND area_name <> '全国'
  AND year = (SELECT MAX(year) FROM e_stat.ssds.g_pref_culture WHERE cat01 = 'G1201')
GROUP BY area_name
ORDER BY community_centers DESC
LIMIT 10
```

## 全国の公民館数の推移

```sql
SELECT year, MAX(value) AS community_centers
FROM e_stat.ssds.g_pref_culture
WHERE cat01 = 'G1201' AND area_name = '全国'
GROUP BY year
ORDER BY year
```
