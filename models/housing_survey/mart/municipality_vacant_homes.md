---
$schema: https://queria.io/schemas/table/v1.json
table: housing_survey.municipality_vacant_homes
title: 市区町村別 空き家の種類・建て方・構造・腐朽破損の有無別空き家数（令和5年住宅・土地統計調査）
description: |-
  令和5年住宅・土地統計調査の空き家数を、全国・都道府県・市区町村別に、空き家の種類・住宅の建て方・建物の構造・腐朽・破損の有無で分けたテーブルです。

  - 標本調査の推定値です
  - 市区町村の行は一部の町村を含まないので、足しても都道府県の値になりません
keywords:
  - e-stat
  - 住宅・土地統計調査
  - 空き家
  - 賃貸用の空き家
  - 二次的住宅
  - 腐朽・破損
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
  - name: vacancy_type_code
    title: 空き家の種類コード
    description: 0 総数、1 賃貸・売却用及び二次的住宅を除く空き家、2 賃貸用の空き家、3 売却用の空き家、4 二次的住宅。総数は 1〜4 の合計
  - name: vacancy_type
    title: 空き家の種類
  - name: decay_code
    title: 腐朽・破損の有無コード
    description: 0 総数、1 腐朽・破損あり、2 腐朽・破損なし
  - name: decay
    title: 腐朽・破損の有無
  - name: building_type_code
    title: 住宅の建て方コード
    description: 0 総数、2 一戸建、3 長屋建・共同住宅・その他
  - name: building_type
    title: 住宅の建て方
  - name: structure_code
    title: 建物の構造コード
    description: 0 総数、1 木造、2 非木造
  - name: structure
    title: 建物の構造
  - name: vacant_homes
    title: 空き家数
    description: 空き家数（戸）。標本調査の推定値で、10戸単位に丸めてある（全国・都道府県・政令指定都市は100戸単位）。原典の「-」は NULL
    semantic: {role: measure, agg: sum}
themes: [housing_land]
---

# 住宅・土地統計調査 空き家数

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| municipality_vacant_homes | 空き家数を空き家の種類（4区分）・腐朽破損の有無・住宅の建て方・建物の構造で分けた表。全国・都道府県・市区町村。2023年 | area / area_name / area_level / parent_area / vacancy_type_code / vacancy_type / decay_code / decay / building_type_code / building_type / structure_code / structure / vacant_homes |

令和5年住宅・土地統計調査の統計表 0004021631 です。市区町村の行は全市・特別区・政令指定都市の区と、
人口1万5千人以上の町村などだけで、全町村は載りません。標本調査の推定値で、10戸単位に丸めてあります。

```sql
-- 賃貸用の空き家が空き家全体に占める割合が高い市区町村
SELECT area, area_name,
    round(100.0 * sum(vacant_homes) FILTER (WHERE vacancy_type_code = '2')
        / sum(vacant_homes) FILTER (WHERE vacancy_type_code = '0'), 1) AS rental_pct
FROM e_stat.housing_survey.municipality_vacant_homes
WHERE decay_code = '0' AND building_type_code = '0' AND structure_code = '0'
    AND ((area_level = 'municipality' AND area <> '13100')
        OR (area_level = 'ward' AND area LIKE '131%'))
GROUP BY area, area_name
ORDER BY rental_pct DESC
LIMIT 10;
```

## 計と内訳が同じ列に並ぶ

4つの軸とも、総数（コード 0）と内訳が同じ列にあります。集計するときは使わない軸を総数（0）に固定します。
固定しないと、総数と内訳を足して二重に数えます。

## 政令指定都市と東京23区は全体と区の両方がある

area_level = 'municipality' は政令指定都市を市全体で、東京の23区を特別区部（13100）の1行で持ちます。area_level = 'ward' は政令指定都市の区と特別区です。両方を足すと二重に数えます。

## 標本調査の誤差

住宅・土地統計調査は標本調査で、小さい地域ほど推定値の誤差が大きくなります。市区町村の空き家数の差や順位は、
総務省統計局が公表する標準誤差率の表で誤差を確かめてから論じてください。

出典: 総務省統計局 令和5年住宅・土地統計調査。
https://www.e-stat.go.jp/stat-search/database?statdisp_id=0004021631

## 補足: housing_survey.municipality_vacant_homes

令和5年住宅・土地統計調査の、全国・都道府県・市区町村別の空き家数を、空き家の種類（4区分）・腐朽・破損の有無・住宅の建て方・建物の構造で分けた表。
縦持ちで、1地域 = 空き家の種類5区分 × 腐朽破損3区分 × 建て方3区分 × 構造3区分（総数を含む、最大135行）。
2023年10月1日現在。
住宅・土地統計調査は標本調査で、値は推定値（10戸単位に丸めてある）。
都道府県の全域を覆うのは都道府県の行だけで、市区町村の行を足しても都道府県の値にはならない。
area_level が municipality の行と ward の行を両方足すと二重に数える。
原典の「-」（該当する数字が無い、または得られない）は vacant_homes が NULL になる。
