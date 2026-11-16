---
$schema: https://queria.io/schemas/table/v1.json
table: rail_transport.passengers_monthly
title: 業態別の鉄道旅客数量（月次）
description: |-
  鉄道輸送統計調査の業態別・月別の旅客数量（千人）を、定期・定期外に分けて2020年4月から持つテーブルです。全国の値です。

  - 業態と定期・定期外に計と内訳が並ぶので、絞ってから合計してください。新幹線は JR の内数です
keywords:
  - e-stat
  - 鉄道輸送統計調査
  - 鉄道
  - 旅客
  - 輸送人員
  - 定期
  - ＪＲ
  - 民鉄
  - 新幹線
  - 月次
sources:
  - path: https://www.e-stat.go.jp/dbview?sid=0003423105
fields:
  - name: operator_type_code
    title: 業態コード
    description: "業態のコード。160=計、100=ＪＲ旅客会社、110=新幹線、120=民鉄（ＪＲ以外）、130=大手、140=中小、150=公営"
  - name: operator_type_name
    title: 業態
    description: "operator_type_code に対応する業態名"
  - name: operator_type_level
    title: 業態の段
    description: "業態の段。1=計、2=ＪＲ旅客会社・民鉄、3=新幹線・大手・中小・公営。業態をまたいで足すときは1つの段に絞る。段3の新幹線はＪＲ旅客会社の一部だけなので、段3を足してもＪＲ旅客会社にはならない"
  - name: operator_type_parent_code
    title: 親の業態コード
    description: "1つ上の業態のコード。計は NULL、ＪＲ旅客会社・民鉄は NULL、新幹線は 100、大手・中小・公営は 120"
  - name: ticket_type_code
    title: 定期・定期外コード
    description: "定期・定期外のコード。100=計、110=定期、120=定期外"
  - name: ticket_type_name
    title: 定期・定期外
    description: "ticket_type_code に対応する名称"
  - name: time
    title: 時間軸コード
    description: "e-Stat の時間軸コード。2024000404 が2024年4月"
  - name: time_name
    title: 時間軸名
    description: "時間軸の名称（2024年4月 など）"
  - name: year
    title: 年
    description: "time から切り出した西暦4桁。年度ではなく暦年"
  - name: month
    title: 月
    description: "time から切り出した月（1〜12）。年度で集計するときは4月〜翌年3月を同じ年度に数える"
  - name: passengers
    title: 旅客数量
    description: "その月の旅客数量（千人）。千人未満を丸めた値で、定期と定期外を足すと計と最大9千人ずれる"
    semantic: {role: measure, agg: sum}
themes: [transport_tourism]
---

# 鉄道輸送統計調査 業態別の鉄道旅客数量

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| passengers_monthly | 鉄道・軌道の旅客数量（千人）。業態別・定期／定期外別・月次の全国の値。2020年4月〜 | operator_type_code / operator_type_name / operator_type_level / operator_type_parent_code / ticket_type_code / ticket_type_name / time / time_name / year / month / passengers |

国土交通省の鉄道輸送統計調査のうち、旅客営業キロ及び旅客数量（業態別）の月次の表から旅客数量を取り込んでいます。
ＪＲ旅客会社（うち新幹線）と民鉄（大手・中小・公営）の業態ごとに、定期と定期外に分けた全国の値で、
75か月 × 7業態 × 3区分の1,575行です。地域の内訳はありません。

```sql
-- 年度ごとの旅客数量と、そのうち定期の割合
SELECT CASE WHEN month >= 4 THEN year ELSE year - 1 END AS fiscal_year,
    sum(passengers) FILTER (WHERE ticket_type_code = '100') AS passengers,
    round(100.0 * sum(passengers) FILTER (WHERE ticket_type_code = '110')
        / sum(passengers) FILTER (WHERE ticket_type_code = '100'), 1) AS commuter_pct
FROM e_stat.rail_transport.passengers_monthly
WHERE operator_type_code = '160'
GROUP BY fiscal_year
HAVING count(*) = 36
ORDER BY fiscal_year;
```

2020年度の17,669,659千人から2025年度の24,093,378千人へ増え、定期の割合は63.7%から54.9%へ下がっています。

```sql
-- 2020年度から2025年度にかけての定期外の旅客数量の伸び（業態別）
SELECT operator_type_name,
    sum(passengers) FILTER (WHERE (year = 2020 AND month >= 4) OR (year = 2021 AND month <= 3)) AS fy2020,
    sum(passengers) FILTER (WHERE (year = 2025 AND month >= 4) OR (year = 2026 AND month <= 3)) AS fy2025,
    round(fy2025 / fy2020, 2) AS ratio
FROM e_stat.rail_transport.passengers_monthly
WHERE ticket_type_code = '120' AND operator_type_level >= 2
GROUP BY operator_type_name
ORDER BY ratio DESC;
```

新幹線の定期外が3.14倍で最も伸び、ＪＲ旅客会社全体は1.80倍、民鉄（ＪＲ以外）は1.64倍です。

## 計と内訳が同じ列に並ぶ

業態は3段です。operator_type_level が1の計（160）は、2のＪＲ旅客会社（100）と民鉄（120）の和に一致し、
民鉄は3の大手・中小・公営（130〜150）の和に一致します（全月で実測）。新幹線（110）はＪＲ旅客会社の内数で、
新幹線以外のＪＲの内訳はありません。業態をまたいで足すときは1つの段に絞ります。

定期・定期外も ticket_type_code が100の計と、110の定期・120の定期外が並びます。千人未満を丸めた値なので、
定期と定期外を足すと計と最大9千人ずれます。

## 年度で数えるときは4月始まり

year は暦年です。年度で集計するときは4月〜翌年3月を同じ年度に数えます。月を足した年度計は、年度別の
旅客数量の表（[sid=0003440001](https://www.e-stat.go.jp/dbview?sid=0003440001)）と2020〜2024年度の
すべての業態・定期区分で一致します。

出典: 国土交通省 鉄道輸送統計調査。
https://www.e-stat.go.jp/statistics/00600350

## 補足: rail_transport.passengers_monthly

鉄道・軌道の旅客を、ＪＲ旅客会社（うち新幹線）と民鉄（大手・中小・公営）の業態ごとに、定期・定期外に分けて数えた全国の値。
業態と定期・定期外はどちらも計と内訳が同じ列に並ぶので、足すときは段（operator_type_level）とticket_type_code で絞る。
