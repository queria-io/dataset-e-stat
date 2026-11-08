---
title: 商業動態統計調査 業種別の商業販売額（月次）
order: 52
---

# 商業動態統計調査 業種別の商業販売額（月次）

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| sales_by_business_monthly | 業種別の商業販売額（10億円）と前年同月比（前年同月=100）。1980年1月〜 | time / year / month / business / business_level / sector / sales_billion_yen / yoy_index |

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
