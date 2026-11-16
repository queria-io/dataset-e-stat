---
$schema: https://queria.io/schemas/table/v1.json
table: port.cargo_tonnage_annual
title: 港別の海上出入貨物トン数（年次）
description: |-
  港湾調査の甲種港湾の港別・年別の海上出入貨物トン数を持つテーブルです。2010〜2023年（2018年を除く）です。

  - 都道府県と港の行が同じ列に並ぶので、area_level で絞ってから合計してください
keywords:
  - e-stat
  - 港湾調査
  - 港湾統計
  - 港湾
  - 甲種港湾
  - 貨物
  - 取扱貨物量
  - 輸出
  - 輸入
  - 移出
  - 移入
  - フェリー
sources:
  - path: https://www.e-stat.go.jp/dbview?sid=0003130803
fields:
  - name: area_code
    title: 地域コード
    description: "港湾調査の港湾コード（5桁）。先頭2桁が都道府県コードで、末尾3桁が000の行は都道府県の計、それ以外は甲種港湾"
  - name: area_level
    title: 地域の段
    description: "2=都道府県の計、3=甲種港湾。県の行はその県の港の和なので、足すときはどちらかに絞る"
  - name: prefecture_code
    title: 都道府県コード
    description: "area_code の先頭2桁（JIS の都道府県コード）"
    semantic: {role: entity, name: prefecture}
  - name: prefecture_name
    title: 都道府県名
    description: "港が属する都道府県の名前"
  - name: port_name
    title: 港名
    description: "港の名前（名古屋、千葉 など）。都道府県の行は NULL"
  - name: flow_code
    title: 輸移出入コード
    description: "輸移出入のコード。100=合計、110=輸出、120=輸入、130=移出、140=移入。合計は4つの内訳の和に一致する"
  - name: flow_name
    title: 輸移出入
    description: "flow_code に対応する名称"
  - name: time
    title: 時間軸コード
    description: "e-Stat の時間軸コード。2023000000 が2023年"
  - name: year
    title: 年
    description: "time から切り出した西暦4桁。暦年"
  - name: cargo_tons
    title: 海上出入貨物トン数
    description: "その港・年・輸移出入の貨物の総トン数（トン）。原典に輸送形態の計の行があればその値、無ければ一般と自動車航送船の和。どちらも「-」（該当数字がない）なら NULL"
    semantic: {role: measure, agg: sum}
  - name: cargo_tons_is_derived
    title: 合計を補ったか
    description: "true なら cargo_tons は原典の計ではなく、一般と自動車航送船の和で補った値"
  - name: general_tons
    title: 一般貨物トン数
    description: "自動車航送船以外の船で運んだ貨物のトン数（トン）。原典が「-」なら NULL"
    semantic: {role: measure, agg: sum}
  - name: ferry_tons
    title: 自動車航送船貨物トン数
    description: "フェリーなど自動車航送船で運んだ貨物のトン数（トン）。原典が「-」なら NULL"
    semantic: {role: measure, agg: sum}
  - name: transshipment_tons
    title: T/S貨物トン数
    description: "一般貨物のうち、積み替え（T/S、トランシップ）の貨物のトン数（トン）。general_tons の内数。原典が「-」なら NULL"
    semantic: {role: measure, agg: sum}
themes: [transport_tourism]
---

# 港湾調査 港別の海上出入貨物トン数

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| cargo_tonnage_annual | 甲種港湾の港別・輸移出入別・年次の海上出入貨物トン数（トン）。2010年〜（2018年を除く） | area_code / area_level / prefecture_code / prefecture_name / port_name / flow_code / flow_name / time / year / cargo_tons / cargo_tons_is_derived / general_tons / ferry_tons / transshipment_tons |

国土交通省の港湾調査（年報）のうち、甲種港湾の海上出入貨物表（トン数総数表）を取り込んでいます。
港ごとに輸出・輸入・移出・移入とその合計を1年1行で持ち、各年160〜166港と、その港を足した
都道府県の行が入ります。乙種港湾は入っていません。

```sql
-- 2023年に取扱貨物量が多い甲種港湾と、そのうち輸出入の割合
SELECT prefecture_name, port_name,
    max(cargo_tons) FILTER (WHERE flow_code = '100') AS cargo_tons,
    round(100.0 * sum(cargo_tons) FILTER (WHERE flow_code IN ('110', '120'))
        / max(cargo_tons) FILTER (WHERE flow_code = '100'), 1) AS foreign_pct
FROM e_stat.port.cargo_tonnage_annual
WHERE area_level = 3 AND year = 2023
GROUP BY prefecture_name, port_name
ORDER BY cargo_tons DESC
LIMIT 5;
```

名古屋が157,844,606トンで最も多く、千葉・苫小牧・横浜・北九州が続きます。輸出入の割合は横浜の70.7%、
名古屋の69.1%に対し、苫小牧は16.1%で、国内の移出入が大半です。

```sql
-- 甲種港湾の取扱貨物量の推移（全国）
SELECT year, sum(cargo_tons) AS cargo_tons
FROM e_stat.port.cargo_tonnage_annual
WHERE area_level = 3 AND flow_code = '100'
GROUP BY year
ORDER BY year;
```

2013年の2,740,016,979トンが最も多く、2023年は2,363,104,727トンです。

## 計の行が無い港は内訳から補っている

原典は輸送形態（一般・自動車航送船）ごとに値を持ち、その計の行を出さない港が多くあります。2023年は
165港のうち85港で計の行がありません。原典の計だけを足すと、2023年の合計は1,554,992,813トンに
とどまり、全国2位の千葉港も落ちます。cargo_tonnage_annual では、計の行が無いときに一般と自動車航送船の
和を cargo_tons に入れ、cargo_tons_is_derived を true にしています。一般と自動車航送船の値は
general_tons と ferry_tons にそのまま残しています。

## 都道府県の行と港の行が同じ列に並ぶ

area_level が2の行は都道府県の計で、その県の甲種港湾（area_level が3）の cargo_tons の和に、すべての年・
輸移出入で一致します（実測）。県をまたいで足すときも、港で足すときも、どちらかの段に絞ります。
輸移出入も flow_code が100の合計と、110〜140の輸出・輸入・移出・移入が並び、合計は4つの和に一致します。

## 2018年は収録していない

原典の2018年の値は崩れています。名古屋の計が2,272,043トン（前後の年は約1.9億トン）、自動車航送船が
63,860,975トン（前後の年は約400万トン）になっているほか、10県で県の行が港の和と合いません。
このため2018年は取り込んでいません。

出典: 国土交通省 港湾調査。
https://www.e-stat.go.jp/statistics/00600280

## 補足: port.cargo_tonnage_annual

港湾調査（年報）の甲種港湾の港別・年別の海上出入貨物トン数（トン）。
輸出・輸入・移出・移入とその合計を、港ごとに1年1行で持つ。
都道府県の行（area_level=2）と港の行（area_level=3）が同じ列に並び、県の行はその県の甲種港湾の和に一致する。
輸移出入も flow_code=100 の合計と内訳が並ぶ。
原典は自動車航送船の取扱いが無い港など、輸送形態の計の行を出さないことが多い。
そのときのcargo_tons は一般と自動車航送船の和で補い、cargo_tons_is_derived を true にする。
収録は2010〜2023年のうち2018年を除く13年で、各年160〜166港。
2018年は原典の値が崩れている（名古屋の計が前後の年の約80分の1になるなど）ので収録していない。
