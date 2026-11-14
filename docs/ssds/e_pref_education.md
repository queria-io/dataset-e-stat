# E 教育

学校数、学級数、教員数、在学者数など、教育に関する指標を収録します。

- 都道府県: `e_stat.ssds.e_pref_education`
- 市区町村: `e_stat.ssds.e_municipal_education`（廃置分合処理済）

項目定義: [社会・人口統計体系 E](https://www.e-stat.go.jp/koumoku/koumoku_teigi/E)

## 代表的な指標

| cat01 | 指標 |
|-------|------|
| E1101 | 幼稚園数 |
| E1301 | 幼稚園教員数 |
| E1401 | 幼稚園定員数 |

学校種別（小学校・中学校・高校など）ごとに指標が分かれます。`item_catalog`（`table_title = 'Ｅ　教育'`）で探してください。

## 都道府県別の幼稚園数ランキング（最新年）

```sql
SELECT area_name, MAX(value) AS kindergartens
FROM e_stat.ssds.e_pref_education
WHERE cat01 = 'E1101'
  AND area_name <> '全国'
  AND year = (SELECT MAX(year) FROM e_stat.ssds.e_pref_education WHERE cat01 = 'E1101')
GROUP BY area_name
ORDER BY kindergartens DESC
LIMIT 10
```

## 全国の幼稚園数の推移

```sql
SELECT year, MAX(value) AS kindergartens
FROM e_stat.ssds.e_pref_education
WHERE cat01 = 'E1101' AND area_name = '全国'
GROUP BY year
ORDER BY year
```
