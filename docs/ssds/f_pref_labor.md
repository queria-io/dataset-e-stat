# F 労働

労働力人口、就業者数、産業別就業者など、労働に関する指標を収録します。

- 都道府県: `e_stat.ssds.f_pref_labor`
- 市区町村: `e_stat.ssds.f_municipal_labor`（廃置分合処理済）

項目定義: [社会・人口統計体系 F](https://www.e-stat.go.jp/koumoku/koumoku_teigi/F)

## 代表的な指標

| cat01 | 指標 |
|-------|------|
| F1101 | 労働力人口 |
| F1102 | 就業者数 |
| F1106 | 就業者数・休業者 |

## 都道府県別の就業者数ランキング（最新年）

```sql
SELECT area_name, MAX(value) AS workers
FROM e_stat.ssds.f_pref_labor
WHERE cat01 = 'F1102'
  AND area_name <> '全国'
  AND year = (SELECT MAX(year) FROM e_stat.ssds.f_pref_labor WHERE cat01 = 'F1102')
GROUP BY area_name
ORDER BY workers DESC
LIMIT 10
```

## 全国の労働力人口の推移

```sql
SELECT year, MAX(value) AS labor_force
FROM e_stat.ssds.f_pref_labor
WHERE cat01 = 'F1101' AND area_name = '全国'
GROUP BY year
ORDER BY year
```
