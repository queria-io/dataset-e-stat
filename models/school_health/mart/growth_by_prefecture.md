---
$schema: https://queria.io/schemas/table/v1.json
table: school_health.growth_by_prefecture
title: 都道府県別の身長・体重の平均値（5〜17歳）
description: |-
  学校保健統計調査の5〜17歳の身長・体重・座高の平均値と標準偏差を、都道府県別・男女別に1996年度から持つテーブルです。

  - 標本調査なので、都道府県どうしの小さな差を順位として読まないでください
  - 2020〜2023年度は測定時期が違い、ほかの年度と単純に比較できません
keywords:
  - e-stat
  - 学校保健統計調査
  - 身長
  - 体重
  - 座高
  - 発育
  - 子ども
  - 児童
  - 生徒
  - 都道府県
sources:
  - path: https://www.e-stat.go.jp/stat-search/files?toukei=00400002
fields:
  - name: year
    title: 調査年度
    description: 調査年度（西暦4桁）。1996〜2025。健康診断は例年4月1日〜6月30日（2020〜2023年度は年度末まで延長）
  - name: age
    title: 年齢
    description: 年齢（歳）。5〜17。各年度4月1日現在の満年齢
  - name: sex_code
    title: 男女コード
    description: 男女コード。1=男、2=女
  - name: sex
    title: 男女
    description: sex_code に対応する名称
  - name: area
    title: 地域コード
    description: 地域コード（5桁）。00000=全国、XX000=都道府県
    semantic: {role: entity, name: prefecture}
  - name: area_name
    title: 地域名
    description: 地域名（全国、北海道、青森県 など）
  - name: prefecture_code
    title: 都道府県コード
    description: 都道府県コード（2桁）。全国は NULL
    semantic: {role: entity, name: prefecture}
  - name: height_mean
    title: 身長の平均値
    description: 身長の平均値（cm）。小数1位
  - name: height_sd
    title: 身長の標準偏差
    description: 身長の標準偏差（cm）。小数2位
  - name: weight_mean
    title: 体重の平均値
    description: 体重の平均値（kg）。小数1位
  - name: weight_sd
    title: 体重の標準偏差
    description: 体重の標準偏差（kg）。小数2位
  - name: sitting_height_mean
    title: 座高の平均値
    description: 座高の平均値（cm）。小数1位。2016年度以降は調査項目に無く NULL
  - name: sitting_height_sd
    title: 座高の標準偏差
    description: 座高の標準偏差（cm）。小数2位。2016年度以降は調査項目に無く NULL
themes: [education_culture]
---

# 学校保健統計調査（growth_by_prefecture）

5〜17歳の身長・体重・座高の平均値と標準偏差を、都道府県別・年齢別・男女別に収録します。

- `e_stat.school_health.growth_by_prefecture`: 37,440行

収録は1996〜2025年度です。年齢は各年度4月1日現在の満年齢です。

出典: [文部科学省 学校保健統計調査](https://www.e-stat.go.jp/stat-search/files?toukei=00400002)

## 17歳の身長の推移

```sql
SELECT year, sex, height_mean
FROM e_stat.school_health.growth_by_prefecture
WHERE area = '00000' AND age = 17
ORDER BY sex_code, year
```

17歳の全国平均は30年度を通じて男子170.6〜170.9cm、女子157.8〜158.1cmに収まります。

## 標本調査であること

在学者から抜いた標本の集計です。2006〜2025年度の表の注では、1県あたりの調査対象者は1つの年齢・男女で186〜1,284人です。都道府県の平均値の年度差や県どうしの差は標準偏差（身長で4〜9cm）に比べて小さいことが多く、標本の誤差の内側にある差を順位として読まないでください。

## 測定時期が違う年度

健康診断は例年4月1日〜6月30日に行いますが、2020〜2023年度は新型コロナウイルス感染症の影響で年度末まで延長されました。成長の早い時期に測定時期がずれるので、ほかの年度と単純に比較できません。11歳男子の全国の体重は2019年度38.7kg、2020年度40.4kg、2021年度39.6kgです。

## 欠けている値

座高は2015年度を最後に調査項目から外れたので、2016年度以降は NULL です。2011年度の岩手県・宮城県・福島県は東日本大震災の影響で調査していないため、すべての値が NULL です。

## 丸め

1999・2000・2011年度の原典ファイルには表示より細かい桁を持つセルがあり、公表の桁（平均値は小数1位、標準偏差は小数2位）に四捨五入しています。

## 補足: 学校保健統計調査 都道府県別の身長・体重（school_health スキーマ）

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| growth_by_prefecture | 身長・体重・座高の平均値と標準偏差。都道府県別・年齢（5〜17歳）別・男女別。1996〜2025年度 | year / age / sex_code / area / area_name / prefecture_code / height_mean / height_sd / weight_mean / weight_sd / sitting_height_mean / sitting_height_sd |

文部科学省の学校保健統計調査のうち、都道府県表の「都道府県別 身長・体重の平均値及び標準偏差」です。
年度・年齢・男女・地域（全国と47都道府県）ごとに1行で、37,440行です。年齢は各年度4月1日現在の満年齢です。

## 補足: school_health.growth_by_prefecture

年齢は5〜17歳（各年度4月1日現在の満年齢）、地域は全国と47都道府県。
収録は1996年度〜2025年度の30年度、37,440行。
2025年度の全国の17歳の身長は男 170.6cm・女 157.9cm（1996年度 170.9cm・158.1cm）。
2020〜2023年度は新型コロナウイルス感染症の影響で、例年4〜6月に行う健康診断を年度末まで延長して実施した。
