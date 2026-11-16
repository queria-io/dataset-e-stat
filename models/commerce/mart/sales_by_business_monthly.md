---
$schema: https://queria.io/schemas/table/v1.json
table: commerce.sales_by_business_monthly
title: 業種別の商業販売額（月次）
description: |-
  経済産業省 商業動態統計調査の業種別商業販売額と前年同月比を、月ごと・業種ごとに持つテーブルです。1980年1月から最新の公表月まで収録しています。

  - 商業計・卸売業計・小売業計と各業種が同じ列に並ぶので、business_level で絞ってから合計してください
  - 原典の注のとおり、分類の改訂や水準の調整で時系列に断層がある月があります（2020年3月、2025年1月など）
keywords:
  - e-stat
  - 商業動態統計
  - 経済産業省
  - 商業販売額
  - 卸売
  - 小売
  - 月次
sources:
  - path: https://www.e-stat.go.jp/stat-search/files?toukei=00550030
fields:
  - name: time
    title: 時間軸コード
    description: 時間軸コード（YYYY00MMMM。2026000808 = 2026年8月）
  - name: year
    title: 年
    description: 暦年（西暦4桁）
  - name: month
    title: 月
    description: 月（1〜12）
  - name: business_order
    title: 業種の並び
    description: 原典の列の並び（0 から）。段（business_level）はこの並びで決めている
  - name: business
    title: 業種
    description: 業種名（商業計、卸売業計、各種商品卸売業 など31区分）
  - name: business_en
    title: 業種（英語）
    description: 原典の英語の業種名
  - name: business_level
    title: 業種の段
    description: total=商業計、sector=卸売業計・小売業計、business=各業種、sub_business=機械器具卸売業の内訳（産業機械器具・自動車・電気機械器具・その他）、reference=小売業の一部をまとめた参考の計。段の違う行が同じ列に並ぶので、段で絞ってから合計する
  - name: sector
    title: 卸売・小売
    description: 卸売業 または 小売業。商業計・卸売業計・小売業計の行は NULL
  - name: sales_billion_yen
    title: 販売額
    description: 販売額（10億円）。原典の「***」（集計に必要なデータが無い）と「X」（秘匿）は NULL
  - name: yoy_index
    title: 前年同月比
    description: 販売額の前年同月比。前年同月を100とした値（101.1 = 1.1%増）
  - name: source_sha256
    title: 元のファイル
    description: この行を作った Excel ファイルの sha256。source_file の sha256 と結合すると、取得した URL と日時を確認できる
themes:
  - economy
---

# 商業動態統計調査 業種別の商業販売額（月次）

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| sales_by_business_monthly | 業種別の商業販売額（10億円）と前年同月比（前年同月=100）。1980年1月〜 | time / year / month / business / business_level / sector / sales_billion_yen / yoy_index |
| source_file | 取得したファイルの一覧。1 行が 1 つのファイル | url / page_url / sha256 / bytes / retrieved_at |

経済産業省の商業動態統計調査のうち、業種別商業販売額の時系列です。毎月の公表で過去の月も直るので、
毎日の更新で全期間を取り直して置き換えます。

## 業種の段

商業計・卸売業計・小売業計と各業種が同じ列に並びます。`business_level` で絞ってから合計します。
商業計 = 卸売業計 + 小売業計、卸売業計 = 卸売の各業種（business）の和です。機械器具卸売業の内訳
（産業機械器具・自動車・電気機械器具・その他）は `sub_business` です。

小売業計は、2010年7月からは小売の各業種の和に一致します。それより前は医薬品・化粧品小売業などが
空欄で、自動車・機械器具・燃料・医薬品化粧品・その他の小売業の合計は参考１の行（`reference`）にあります。

```sql
-- 小売の業種別の販売額（2026年8月）
SELECT business, sales_billion_yen, yoy_index
FROM e_stat.commerce.sales_by_business_monthly
WHERE time = '2026000808' AND sector = '小売業' AND business_level = 'business'
ORDER BY sales_billion_yen DESC;
```

## 時系列の断層

原典の注のとおり、分類の改訂や調査の見直しで販売額の水準が途中で変わっている月があります
（1998年4月、1999年4月、2015年7月、2020年3月、2025年1月など）。前年同月比は原典が断層を調整して
出している値なので、長い期間の伸びを見るときは前年同月比を使います。
