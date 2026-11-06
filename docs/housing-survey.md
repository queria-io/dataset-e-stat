---
title: 住宅・土地統計調査 世帯の年間収入階級・住宅の所有の関係別主世帯数
order: 44
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
