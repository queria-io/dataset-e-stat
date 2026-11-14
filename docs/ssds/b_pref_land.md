# B 自然環境

総面積、可住地面積、林野・森林面積、湖沼面積などの土地に関する指標を収録します。

- 都道府県: `e_stat.ssds.b_pref_land`
- 市区町村: `e_stat.ssds.b_municipal_land`（廃置分合処理済）

項目定義: [社会・人口統計体系 B](https://www.e-stat.go.jp/koumoku/koumoku_teigi/B)

## 代表的な指標

| cat01 | 指標 |
|-------|------|
| B1101 | 総面積（北方地域及び竹島を除く） |
| B1103 | 可住地面積 |
| B1105 | 林野面積 |
| B1106 | 森林面積 |

## 都道府県別の可住地面積ランキング（最新年）

```sql
SELECT area_name, MAX(value) AS habitable_area
FROM e_stat.ssds.b_pref_land
WHERE cat01 = 'B1103'
  AND area_name <> '全国'
  AND year = (SELECT MAX(year) FROM e_stat.ssds.b_pref_land WHERE cat01 = 'B1103')
GROUP BY area_name
ORDER BY habitable_area DESC
LIMIT 10
```

## 全国の総面積の推移

```sql
SELECT year, MAX(value) AS total_area
FROM e_stat.ssds.b_pref_land
WHERE cat01 = 'B1101' AND area_name = '全国'
GROUP BY year
ORDER BY year
```
