# K 安全

消防、警察、災害、交通事故など、安全に関する指標を収録します。

- 都道府県: `e_stat.ssds.k_pref_safety`
- 市区町村: `e_stat.ssds.k_municipal_safety`（廃置分合処理済）

項目定義: [社会・人口統計体系 K](https://www.e-stat.go.jp/koumoku/koumoku_teigi/K)

## 代表的な指標

| cat01 | 指標 |
|-------|------|
| K1101 | 消防本部・署数 |
| K1102 | 消防職員数 |
| K1105 | 消防団員数 |

## 都道府県別の消防職員数ランキング（最新年）

```sql
SELECT area_name, MAX(value) AS firefighters
FROM e_stat.ssds.k_pref_safety
WHERE cat01 = 'K1102'
  AND area_name <> '全国'
  AND year = (SELECT MAX(year) FROM e_stat.ssds.k_pref_safety WHERE cat01 = 'K1102')
GROUP BY area_name
ORDER BY firefighters DESC
LIMIT 10
```

## 全国の消防職員数の推移

```sql
SELECT year, MAX(value) AS firefighters
FROM e_stat.ssds.k_pref_safety
WHERE cat01 = 'K1102' AND area_name = '全国'
GROUP BY year
ORDER BY year
```
