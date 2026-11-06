---
title: 医療施設調査 市区町村別の病院・診療所の数と病床数
order: 39
---

# 医療施設調査 市区町村別の病院・診療所の数と病床数

病院・一般診療所・歯科診療所の数と病床数を、都道府県・二次医療圏・市区町村ごとに年1行で
収録した表です。2008年から2024年まで（2013年を除く）の36,660行で、毎年10月1日現在の数です。

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| municipality_facility | 地域別の病院数（種類別）・病床数（種類別）・一般診療所数（有床・無床）・歯科診療所数 | survey_year / survey_kind / area_level / area_code / area_name / prefecture_code / medical_area_code / medical_area_name / hospitals / hospital_beds / general_clinics / dental_clinics ほか |

都道府県・二次医療圏・市区町村が同じ表に並び、どの粒度も全域を1回ずつ覆います。
`area_level` で1つに絞ってから合計します。市区町村の行には、その市区町村が属する二次医療圏の
コードと名称が入ります。政令指定都市は区ごとの行だけで、市の行はありません。

```sql
-- 2024年の人口10万人あたりの病院の病床数（二次医療圏別、上位10）
SELECT f.medical_area_name, f.hospital_beds,
       f.hospital_beds * 100000.0 / SUM(c.population) AS beds_per_100k
FROM e_stat.medical_facility.municipality_facility f
JOIN e_stat.medical_facility.municipality_facility m
    ON m.survey_year = f.survey_year AND m.area_level = 'municipality'
    AND m.medical_area_code = f.medical_area_code
JOIN e_stat.census.census_municipality_2025 c ON c.area = m.area_code
WHERE f.survey_year = 2024 AND f.area_level = 'medical_area'
GROUP BY ALL
ORDER BY beds_per_100k DESC
LIMIT 10;
```

人口は区の再編（浜松市、2024年）を反映した令和7年の census_municipality_2025 と結合します。
令和2年の census_municipality では浜松市の新しい区のコードが当たらず、西部の人口が欠けます。

`area_code` は各年の標準地域コードのままです。合併で無くなった市町村の行は、今の
`code.municipality` とはつながりません。`survey_kind` は静態調査の年（3年ごと）と動態調査だけの
年を分けますが、施設数・病床数はどちらの年も全数なので、そのまま年で並べられます。

2013年（平成25年）は取り込んでいません。e-Stat の市町村別の表で市町村と値の対応が崩れていて
（宇都宮市の病院数が前後の年の31に対して5など）、市町村の和が都道府県の値に合わないためです。

この表は毎日の更新（CI）では e-Stat から取らず、手元で1回だけ取り込んでいます
（下の「手元で1回だけ取り込む統計表」）。

出典: 厚生労働省 医療施設調査。https://www.e-stat.go.jp/statistics/00450021

## 補足: medical_facility.municipality_facility

収録は2008年〜2024年（2013年を除く16年）、36,660行。
毎年10月1日現在の数で、病院は病床の種類別、一般診療所は有床・無床別に持つ。
地域は都道府県・二次医療圏・市区町村の3つの粒度が同じ表に並ぶ。
どの粒度も全域を1回ずつ覆い、市区町村の和は二次医療圏・都道府県の値に一致する。
「再掲」の列（療養病床を有する一般病院・地域医療支援病院・救急告示病院など）はほかの列の内訳なので、足すと二重に数える。
原典の「-」（該当なし）は0にしてある。
出典: 厚生労働省 医療施設調査（二次医療圏・市区町村別の病院数・病床数と一般診療所数・歯科診療所数・病床数の表）。
