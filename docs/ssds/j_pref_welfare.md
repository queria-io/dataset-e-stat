# J 福祉・社会保障

生活保護、社会保障給付など、福祉・社会保障に関する指標を収録します。

- 都道府県: `e_stat.ssds.j_pref_welfare`
- 市区町村: `e_stat.ssds.j_municipal_welfare`（廃置分合処理済）

項目定義: [社会・人口統計体系 J](https://www.e-stat.go.jp/koumoku/koumoku_teigi/J)

## 代表的な指標

| cat01 | 指標 |
|-------|------|
| J1101 | 生活保護被保護実世帯数 |
| J1105 | 生活保護被保護実人員 |

## 都道府県別の生活保護被保護実人員ランキング（最新年）

```sql
SELECT area_name, MAX(value) AS recipients
FROM e_stat.ssds.j_pref_welfare
WHERE cat01 = 'J1105'
  AND area_name <> '全国'
  AND year = (SELECT MAX(year) FROM e_stat.ssds.j_pref_welfare WHERE cat01 = 'J1105')
GROUP BY area_name
ORDER BY recipients DESC
LIMIT 10
```

## 全国の生活保護被保護実人員の推移

```sql
SELECT year, MAX(value) AS recipients
FROM e_stat.ssds.j_pref_welfare
WHERE cat01 = 'J1105' AND area_name = '全国'
GROUP BY year
ORDER BY year
```
