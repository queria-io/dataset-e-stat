# I 健康・医療

平均余命、医療施設、医療従事者など、健康・医療に関する指標を収録します。

- 都道府県: `e_stat.ssds.i_pref_health`
- 市区町村: `e_stat.ssds.i_municipal_health`（廃置分合処理済）

項目定義: [社会・人口統計体系 I](https://www.e-stat.go.jp/koumoku/koumoku_teigi/I)

## 代表的な指標

| cat01 | 指標 |
|-------|------|
| I1101 / I1102 | 平均余命（0歳）（男）/（女） |
| I1301 / I1302 | 平均余命（40歳）（男）/（女） |

## 都道府県別の平均余命（0歳・女）ランキング（最新年）

```sql
SELECT area_name, MAX(value) AS life_expectancy
FROM e_stat.ssds.i_pref_health
WHERE cat01 = 'I1102'
  AND area_name <> '全国'
  AND year = (SELECT MAX(year) FROM e_stat.ssds.i_pref_health WHERE cat01 = 'I1102')
GROUP BY area_name
ORDER BY life_expectancy DESC
LIMIT 10
```

## 全国の平均余命（0歳・女）の推移

```sql
SELECT year, MAX(value) AS life_expectancy
FROM e_stat.ssds.i_pref_health
WHERE cat01 = 'I1102' AND area_name = '全国'
GROUP BY year
ORDER BY year
```
