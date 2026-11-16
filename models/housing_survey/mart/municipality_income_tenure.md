---
$schema: https://queria.io/schemas/table/v1.json
table: housing_survey.municipality_income_tenure
title: 市区町村別 世帯の年間収入階級・住宅の所有の関係別主世帯数（令和5年住宅・土地統計調査）
description: |-
  令和5年住宅・土地統計調査の主世帯数を、全国・都道府県・市区町村別に、年間収入階級と住宅の所有の関係で分けたテーブルです。

  - 標本調査の推定値です
  - 市区町村の行は一部の町村を含まないので、足しても都道府県の値になりません
keywords:
  - e-stat
  - 住宅・土地統計調査
  - 年収
  - 世帯の年間収入
  - 持ち家
  - 借家
  - 市区町村
temporal_coverage: {start: "2023", end: "2023"}
sources:
  - path: https://www.e-stat.go.jp/
fields:
  - name: area
    title: 地域コード（5桁）
    description: 標準地域コード。全国は 00000、都道府県は 13000 のように末尾 000
    semantic: {role: entity, name: city}
  - name: area_name
    title: 地域名
  - name: area_level
    title: 地域の粒度
    description: national=全国、prefecture=都道府県、municipality=市町村（政令指定都市は市全体、東京の23区は特別区部 13100 の1行）、ward=政令指定都市の区と東京の特別区（13101〜13123）
  - name: parent_area
    title: 1つ上の地域コード
  - name: tenure_code
    title: 住宅の所有の関係コード
    description: 0 総数、1 持ち家、2 借家、21 公営の借家、22 都市再生機構（UR）・公社の借家、23 民営借家、24 給与住宅。借家（2）は 21〜24 の合計
  - name: tenure
    title: 住宅の所有の関係
  - name: income_class_code
    title: 世帯の年間収入階級コード
    description: 00 総数、01 100万円未満 〜 11 1500万円以上の10区分（04 は欠番）。「不詳」は無いので、10区分の合計は総数より小さい
  - name: income_class
    title: 世帯の年間収入階級
  - name: income_lower
    title: 年収階級の下限（万円）
    description: この金額以上。総数の行は NULL
  - name: income_upper
    title: 年収階級の上限（万円）
    description: この金額未満。1500万円以上と総数の行は NULL
  - name: households
    title: 主世帯数
    description: 主世帯数（世帯）。標本調査の推定値で、10世帯単位に丸めてある。原典の「-」は NULL
    semantic: {role: measure, agg: sum}
themes: [housing_land]
---

# 住宅・土地統計調査 世帯の年間収入階級・住宅の所有の関係別主世帯数

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| municipality_income_tenure | 主世帯数を年収階級（10区分）と住宅の所有の関係で分けた表。全国・都道府県・市区町村。2023年 | area / area_name / area_level / parent_area / tenure_code / tenure / income_class_code / income_class / income_lower / income_upper / households |

令和5年住宅・土地統計調査の統計表 0004021668 です。市区町村の行は全市・特別区・政令指定都市の区と、
人口1万5千人以上の町村などだけで、全町村は載りません。標本調査の推定値で、10世帯単位に丸めてあります。

```sql
-- 年収1000万円以上の主世帯の割合が高い市区町村
SELECT area, area_name,
    round(100.0 * sum(households) FILTER (WHERE income_lower >= 1000)
        / max(households) FILTER (WHERE income_class_code = '00'), 1) AS over_10m_pct
FROM e_stat.housing_survey.municipality_income_tenure
-- 東京の23区は ward なので、特別区部 (13100) の代わりに23区を並べる
WHERE tenure_code = '0'
    AND ((area_level = 'municipality' AND area <> '13100')
        OR (area_level = 'ward' AND area LIKE '131%'))
GROUP BY area, area_name
ORDER BY over_10m_pct DESC
LIMIT 10;
```

## 計と内訳が同じ列に並ぶ

所有の関係は総数（0）・持ち家（1）・借家（2）と借家の内訳（21〜24）が、年収階級は総数（00）と10区分が同じ列にあります。
年収階級に「不詳」の区分は無いので、10区分の合計は総数より小さくなります。割合は総数を分母にするか、10区分の合計を分母にするかを決めてから出します。

## 政令指定都市と東京23区は全体と区の両方がある

area_level = 'municipality' は政令指定都市を市全体で、東京の23区を特別区部（13100）の1行で持ちます。area_level = 'ward' は政令指定都市の区と特別区です。両方を足すと二重に数えます。

出典: 総務省統計局 令和5年住宅・土地統計調査。
https://www.e-stat.go.jp/stat-search/database?statdisp_id=0004021668

## 補足: housing_survey.municipality_income_tenure

令和5年住宅・土地統計調査の、全国・都道府県・市区町村別の主世帯数を、世帯の年間収入階級（10区分）と住宅の所有の関係（持ち家・公営の借家・UR・公社の借家・民営借家・給与住宅）で分けた表。
縦持ちで、1地域 = 所有の関係7区分 × 年収11区分（総数を含む）。
2023年10月1日現在。
住宅・土地統計調査は標本調査で、値は推定値（10世帯単位に丸めてある）。
都道府県の全域を覆うのは都道府県の行だけで、市区町村の行を足しても都道府県の値にはならない。
area_level が municipality の行（政令指定都市は市全体、東京の23区は特別区部 13100）と ward の行（政令指定都市の区・特別区）を両方足すと二重に数える。
原典の「-」（該当する数字が無い、または得られない）は households が NULL になる。
