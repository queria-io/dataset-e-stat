---
$schema: https://queria.io/schemas/table/v1.json
table: medical_facility.municipality_facility
title: 病院・診療所の数と病床数（市区町村・二次医療圏別）
description: |-
  医療施設調査の病院・一般診療所・歯科診療所の数と病床数を、都道府県・二次医療圏・市区町村ごとに年1行で持つテーブルです。2008年から（2013年を除く）です。

  - 3つの粒度が同じ列に並ぶので、area_level で絞ってから合計してください
  - 政令指定都市は区の行だけです
  - 再掲の列はほかの列の内訳です
keywords:
  - e-stat
  - 医療施設調査
  - 病院
  - 診療所
  - 一般診療所
  - 歯科診療所
  - 病床
  - 病床数
  - 二次医療圏
  - 医療
  - 市区町村
  - 都道府県
temporal_coverage: {start: "2008", end: "2024"}
sources:
  - path: https://www.e-stat.go.jp/statistics/00450021
fields:
  - name: survey_year
    title: 調査年
    description: "調査年。毎年10月1日現在。2008〜2024年で、2013年は無い（原典の市町村別の表が崩れているため取り込まない）"
  - name: survey_kind
    title: 調査の種類
    description: "static=静態調査の年（3年ごと: 2008・2011・2014・2017・2020・2023年）、dynamic=動態調査だけの年。施設数・病床数はどちらの年も10月1日現在の全数で、そのまま年で並べて比べられる"
  - name: area_level
    title: 地域の粒度
    description: "prefecture=都道府県（47）、medical_area=二次医療圏（330〜349）、municipality=市区町村（1,892〜1,956）。3つの粒度がそれぞれ全域を1回ずつ覆う。絞らずに合計すると3倍に数える"
  - name: area_code
    title: 標準地域コード（5桁）
    description: "統計に用いる標準地域コード（5桁）。都道府県は 13000 のように末尾が 000。二次医療圏の行は NULL。市区町村はその年のコードで、合併で無くなった市町村のコードも入る（2024年に無いコードは2008年で94、2023年で7）。全国地方公共団体コード（6桁）とは別体系"
    semantic: {role: entity, name: city}
  - name: area_name
    title: 地域名
    description: "地域の名称。政令指定都市は区ごとの行（中央区・北区など）で、市の行は無い。区名だけでは市が分からないので area_code で見分ける"
  - name: prefecture_code
    title: 都道府県コード（2桁）
    description: "都道府県コード（2桁）。どの粒度の行にも入る"
    semantic: {role: entity, name: prefecture}
  - name: medical_area_code
    title: 二次医療圏コード（4桁）
    description: "二次医療圏のコード（4桁、先頭2桁が都道府県）。二次医療圏と市区町村の行に入り、都道府県の行は NULL。市区町村の行にはその市区町村が属する圏が入る。圏の区切りとコードは医療計画の見直しで変わる（圏の数は2008年の348から2024年の330まで）ので、年をまたいで圏を突き合わせるときは名称と構成市区町村も確かめる"
  - name: medical_area_name
    title: 二次医療圏名
    description: "二次医療圏の名称（南渡島・札幌 など）"
  - name: hospitals
    title: 病院数
    description: "病院数（病床20床以上）。精神科病院 + 結核療養所 + 一般病院"
  - name: psychiatric_hospitals
    title: 精神科病院数
    description: "精神科病院数"
  - name: tuberculosis_sanatoriums
    title: 結核療養所数
    description: "結核療養所数。原典の表に区分があるのは2012年まで。2014年以降は NULL"
  - name: general_hospitals
    title: 一般病院数
    description: "一般病院数"
  - name: general_hospitals_with_long_term_care_beds
    title: 療養病床を有する一般病院数
    description: "療養病床を有する一般病院数（一般病院の再掲）"
  - name: regional_support_hospitals
    title: 地域医療支援病院数
    description: "地域医療支援病院数（病院の再掲）"
  - name: emergency_hospitals
    title: 救急告示病院数
    description: "救急告示病院数（病院の再掲）"
  - name: hospital_beds
    title: 病院の病床数
    description: "病院の病床数。精神・感染症・結核・療養・一般の5種の和"
  - name: psychiatric_beds
    title: 精神病床数
    description: "病院の精神病床数"
  - name: infectious_beds
    title: 感染症病床数
    description: "病院の感染症病床数"
  - name: tuberculosis_beds
    title: 結核病床数
    description: "病院の結核病床数"
  - name: long_term_care_beds
    title: 療養病床数
    description: "病院の療養病床数"
  - name: general_beds
    title: 一般病床数
    description: "病院の一般病床数"
  - name: regional_support_hospital_beds
    title: 地域医療支援病院の病床数
    description: "地域医療支援病院の病床数（病院の病床数の再掲）"
  - name: general_clinics
    title: 一般診療所数
    description: "一般診療所数。有床 + 無床"
  - name: general_clinics_with_beds
    title: 有床の一般診療所数
    description: "有床の一般診療所数"
  - name: general_clinics_with_long_term_care_beds
    title: 療養病床を有する一般診療所数
    description: "療養病床を有する一般診療所数（有床の一般診療所の再掲）"
  - name: general_clinics_without_beds
    title: 無床の一般診療所数
    description: "無床の一般診療所数"
  - name: general_clinic_beds
    title: 一般診療所の病床数
    description: "一般診療所の病床数"
  - name: general_clinic_long_term_care_beds
    title: 一般診療所の療養病床数
    description: "一般診療所の療養病床数（一般診療所の病床数の再掲）"
  - name: dental_clinics
    title: 歯科診療所数
    description: "歯科診療所数。有床 + 無床"
  - name: dental_clinics_with_beds
    title: 有床の歯科診療所数
    description: "有床の歯科診療所数"
  - name: dental_clinics_without_beds
    title: 無床の歯科診療所数
    description: "無床の歯科診療所数"
themes: [social_security_health]
---

# 医療施設調査 市区町村別の病院・診療所の数と病床数

病院・一般診療所・歯科診療所の数と病床数を、都道府県・二次医療圏・市区町村ごとに年1行で
収録した表です。2008年から2024年まで（2013年を除く）の36,660行で、毎年10月1日現在の数です。

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| municipality_facility | 地域別の病院数（種類別）・病床数（種類別）・一般診療所数（有床・無床）・歯科診療所数 | survey_year / survey_kind / area_level / area_code / area_name / prefecture_code / medical_area_code / medical_area_name / hospitals / hospital_beds / general_clinics / dental_clinics ほか |

都道府県・二次医療圏・市区町村が同じ表に並び、どの粒度も全域を1回ずつ覆います。
`area_level` で1つに絞ってから合計します。市区町村の行には、その市区町村が属する二次医療圏の
コードと名称が入ります。政令指定都市は区ごとの行だけで、市の行はありません。市でまとめるときは
`soumu.code.municipality` の `municipality_code` で区を束ねます。

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

`area_code` は各年の標準地域コード（5桁）のままで、6桁の全国地方公共団体コードとは別体系です。合併で無くなった市町村の行は、今の
`soumu.code.municipality` とはつながりません。`survey_kind` は静態調査の年（3年ごと）と動態調査だけの
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
