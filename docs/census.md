---
title: 小地域集計（国勢調査）
order: 14
---

# 令和2年国勢調査 小地域集計（census スキーマ）

町丁・字等の単位で、年齢・世帯・住宅・産業を集計したデータです。市区町村より細かい粒度で人の分布を見たいときに使います。境界データと結合すれば、そのまま地図に載せられます。

| テーブル | 内容 | 主分類（cat01） | value |
|---------|------|----------------|-------|
| census_small_area_age | 男女・年齢別人口 | 男女・年齢区分 | 人口 |
| census_small_area_household | 世帯の家族類型別一般世帯数 | 家族類型 | 一般世帯数 |
| census_small_area_industry | 産業大分類別就業者数 | 産業大分類 | 就業者数 |
| census_small_area_housing | 住宅の所有関係別一般世帯数 | 住宅の種類・所有の関係 | 一般世帯数 |
| census_small_area_household_size | 世帯人員別一般世帯数 | 世帯人員 | 一般世帯数・一般世帯人員・1世帯当たり人員 |
| census_small_area_building_type | 住宅の建て方別世帯数 | 住宅の建て方 | 主世帯数 |
| census_small_area_economic_type | 世帯の経済構成別一般世帯数 | 世帯の経済構成 | 一般世帯数 |

7表とも `area` / `area_name` / `area_level` / `cat01` / 主分類名 / `cat02` / 秘匿区分名 / `unit` / `value` の9カラムです。主分類の名称列だけテーブルごとに `age_class` / `family_type` / `industry` / `tenure` / `household_size` / `building_type` / `economic_type` と名前が違います。

`census_small_area_household_size` は `cat01` によって単位が違います。`0010`〜`0060` は世帯数、`0070` は一般世帯人員（人）、`0080` は1世帯当たり人員（人／世帯）です。

出典: [統計GIS 小地域集計](https://www.e-stat.go.jp/gis)

## 地域の粒度は3階層ある

`area` には市区町村・町丁・字等・その内訳が縦に並んでいます。粒度は `area_level` で判別します。

| area_level | 桁数 | 内容 | 地域数 | 総人口 |
|-----------|-----:|------|-------:|-------:|
| municipality | 5 | 市区町村 | 1,896 | 126,146,099 |
| small_area | 9 | 町丁・字等 | 102,874 | 126,146,099 |
| small_area_detail | 11 | 丁目など町丁・字等の内訳 | 148,268 | 80,726,789 |

`municipality` と `small_area` はどちらも全域を覆い、合計が一致します。`small_area_detail` は丁目に分かれている地域にしかないため全域を覆いません。

粒度を混ぜて集計すると二重・三重に数えることになります。

```sql
-- 町丁・字等の粒度で人口の多い順（全域を覆い、重複しない）
SELECT area_name, value AS population
FROM e_stat.census.census_small_area_age
WHERE cat01 = '0010' AND area_level = 'small_area' AND area LIKE '13%'
ORDER BY population DESC
LIMIT 10
```

## 男女は cat01 に入っている

`census_small_area_age` の `cat01` は男女と年齢区分をまとめて表します。総数が `0010`〜`0200`、男が `0210`〜`0400`、女が `0410`〜`0600` です。

各区分の中に「総数、年齢「不詳」含む」と5歳階級と4区分（15歳未満・15〜64歳・65歳以上・75歳以上）が同居しているので、`cat01` を絞らずに合計すると何重にも重複します。

列名が `sex` の列は男女ではなく秘匿・合算区分です（他の3表の `secrecy` と同じもの）。名前が実態と合っていませんが、公開済みのため変えていません。

```sql
-- 高齢化率（65歳以上 / 総数）を町丁・字等の単位で
SELECT
    t.area_name,
    t.value AS population,
    ROUND(100.0 * o.value / NULLIF(t.value, 0), 1) AS pct_65plus
FROM e_stat.census.census_small_area_age t
JOIN e_stat.census.census_small_area_age o
  ON t.area = o.area AND o.cat01 = '0190'   -- 総数65歳以上
WHERE t.cat01 = '0010'                       -- 総数、年齢「不詳」含む
  AND t.area_level = 'small_area'
  AND t.value >= 500
  AND t.area LIKE '08220%'                   -- つくば市
ORDER BY pct_65plus DESC
LIMIT 10
```

## 秘匿された行は 0 で入る

`cat02` は秘匿・合算区分です。1=無し、2=合算、3=秘匿。

秘匿（`cat02 = 3`）の行は `value` が 0 で入りますが「0人」ではなく非公表です。実数は合算（`cat02 = 2`）の地域に含まれています。そのまま合計すると実態より小さくなります。`census_small_area_age` では全行の 2.8% が秘匿です。

```sql
-- 秘匿を除いて数える（合算先には含まれているので総数は変わらない）
SELECT COUNT(*) FILTER (WHERE cat02 = '3') AS hidden, COUNT(*) AS total
FROM e_stat.census.census_small_area_age
WHERE cat01 = '0010' AND area_level = 'small_area'
```

## 境界データと結合して地図にする

`area` は `boundary.small_area` の `key_code` と同じ体系です。

ここが間違えやすいところで、**結合するときは `area_level` で絞らないでください。** `boundary.small_area` は末端の区画だけを1行ずつ持っていて、丁目に分かれている地域は 11桁の行しかありません。`small_area`（9桁）に絞ってから結合すると、全国 1億2614万人のうち 4,530万人（36%）しか残りません。

`area = key_code` でそのまま結合すれば、末端の区画が自然に選ばれます。全国で 220,603 行・1億2603万人になります（境界の無い小地域が 30,539 件あるぶん 0.09% 足りません）。

```sql
-- 高齢化率を境界ポリゴン付きで取り出す（地図用）
SELECT
    b.area_name,
    ROUND(100.0 * o.value / NULLIF(t.value, 0), 1) AS pct_65plus,
    t.value AS population,
    ST_AsText(b.geometry) AS wkt
FROM e_stat.boundary.small_area b
JOIN e_stat.census.census_small_area_age t ON t.area = b.key_code AND t.cat01 = '0010'
JOIN e_stat.census.census_small_area_age o ON o.area = b.key_code AND o.cat01 = '0190'
WHERE b.city_name = 'つくば市' AND t.value >= 500
ORDER BY pct_65plus DESC
LIMIT 20
```

市区町村の単位で足したいだけなら、境界を経由せず `area_level = 'municipality'` の行をそのまま使います。

## 市区町村コードで他のデータとつなぐ

`area` の先頭5桁が標準地域コードです。`code.municipality` や SSDS の市区町村テーブルと突き合わせられます。

```sql
-- 小地域の人口を市区町村名付きで
SELECT m.pref_name, m.municipality_name, SUM(c.value) AS population
FROM e_stat.census.census_small_area_age c
JOIN e_stat.code.municipality m ON SUBSTR(c.area, 1, 5) = m.area_code
WHERE c.cat01 = '0010' AND c.area_level = 'small_area'
GROUP BY m.pref_name, m.municipality_name
ORDER BY population DESC
LIMIT 10
```
