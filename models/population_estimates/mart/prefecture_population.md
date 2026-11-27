# 人口推計 都道府県別の男女別人口

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| prefecture_population | 全国と47都道府県の男女別の総人口・日本人人口（千人）。2005・2010・2015・2020・2021〜2024年の10月1日現在 | area / area_name / area_level / sex_code / sex / population_type_code / population_type / time / year / population |

総務省統計局の人口推計（各年10月1日現在人口、令和2年国勢調査基準）の統計表 0003448232 です。
国勢調査のない年の人口を、都道府県別に年ごとに見られます。

```sql
-- 2020年から2024年の都道府県別の総人口の増減率
SELECT area_name,
    max(population) FILTER (WHERE year = 2024) AS population_2024,
    round(100.0 * (max(population) FILTER (WHERE year = 2024)
        - max(population) FILTER (WHERE year = 2020))
        / max(population) FILTER (WHERE year = 2020), 2) AS change_pct
FROM e_stat.population_estimates.prefecture_population
WHERE area_level = 'prefecture' AND sex_code = '000' AND population_type_code = '001'
GROUP BY area_name
ORDER BY change_pct
LIMIT 5;
```

## 計と内訳が同じ列に並ぶ

男女は男女計（000）と男（001）・女（002）、人口の種類は総人口（001）と日本人人口（002）が同じ列にあります。
使わない軸は男女計・総人口に固定します。固定しないと、計と内訳を足して二重に数えます。
全国（area_level = 'national'）の行も都道府県と同じ列にあるので、都道府県を足すときは area_level で絞ります。

## 2020年までは国勢調査、2021年からは推計

2005年・2010年・2015年・2020年は国勢調査の人口（2020年は基準にした令和2年国勢調査）で、2021年以降は人口推計の値です。

## 基準が変わると過去の値が置き換わる

人口推計は5年に1度、国勢調査の結果で過去の推計値を改定します。このテーブルは令和2年国勢調査基準の値で、
令和7年国勢調査基準の表が公開されても、このテーブルには入りません。

## 千人未満の丸め

値は千人単位に丸めてあります。男と女の和は男女計と最大1千人、都道府県の和は全国と最大3千人（実測）ずれます。

出典: 総務省統計局 人口推計。
https://www.e-stat.go.jp/statistics/00200524
