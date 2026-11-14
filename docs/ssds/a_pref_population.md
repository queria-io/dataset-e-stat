# A 人口・世帯

総人口、年齢別人口、世帯数、婚姻、出生・死亡、転入・転出などの指標を収録します。主な出典は国勢調査、人口推計、人口動態統計、住民基本台帳です。

- 都道府県: `e_stat.ssds.a_pref_population`（1975年〜、47都道府県 + 全国）
- 市区町村: `e_stat.ssds.a_municipal_population`（1980年〜、廃置分合処理済）

項目定義: [社会・人口統計体系 A](https://www.e-stat.go.jp/koumoku/koumoku_teigi/A)

## 代表的な指標

| cat01 | 指標 |
|-------|------|
| A1101 | 総人口 |
| A110101 / A110102 | 総人口（男）/（女） |
| A192001 | 全国総人口に占める人口割合 |

その他の指標は `item_catalog`（`table_title = 'Ａ　人口・世帯'`）で探せます。

## 全国総人口の推移

```sql
SELECT year, MAX(value) AS population
FROM e_stat.ssds.a_pref_population
WHERE cat01 = 'A1101' AND area_name = '全国'
GROUP BY year
ORDER BY year
```

## 都道府県別の総人口ランキング（最新年）

```sql
SELECT area_name, MAX(value) AS population
FROM e_stat.ssds.a_pref_population
WHERE cat01 = 'A1101'
  AND area_name <> '全国'
  AND year = (SELECT MAX(year) FROM e_stat.ssds.a_pref_population WHERE cat01 = 'A1101')
GROUP BY area_name
ORDER BY population DESC
LIMIT 10
```

## 市区町村別の人口（最新年）

```sql
SELECT area_name, MAX(value) AS population
FROM e_stat.ssds.a_municipal_population
WHERE cat01 = 'A1101'
  AND year = (SELECT MAX(year) FROM e_stat.ssds.a_municipal_population WHERE cat01 = 'A1101')
GROUP BY area_name
ORDER BY population DESC
LIMIT 10
```
