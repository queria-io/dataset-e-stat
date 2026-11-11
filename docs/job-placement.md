---
title: 一般職業紹介状況 都道府県別の求人数・求職者数・求人倍率
order: 55
---

# 一般職業紹介状況 都道府県別の求人数・求職者数・求人倍率

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| labor_market_monthly | 都道府県別のハローワークの求人数・求職者数・求人倍率（月次）。受理地別は1963年1月〜、就業地別は2005年2月〜 | year / month / basis / seasonally_adjusted / prefecture_code / active_openings_ratio |
| labor_market_annual | 同じ指標の年平均と年度平均。受理地別は1963年〜、就業地別は2006年〜 | period_type / year / basis / prefecture_code / active_openings_ratio |

厚生労働省の一般職業紹介状況（職業安定業務統計）の長期時系列表のうち、都道府県別の表（受理地別の第11表、
就業地別の第18表）です。新規学卒者を除き、パートタイムを含む一般の値です。毎月の公表で差し替わり、
季節調整値は毎年1月分の公表で過去の月も改定されるので、毎日の更新で全期間を取り直して置き換えます。

## 受理地と就業地

`basis` が `受理地` の行は、求人・求職を受け付けたハローワークの所在地で数えた値です。`就業地` の行は、
求人の働く場所で数えた値です。本社が一括して出す求人は、受理地別では本社の都道府県に数えます。
求職者は受理地でしか数えないので、就業地別の求人倍率は、就業地別の求人数を受理地別の求職者数で割った値です。
就業地別に全国の行はありません。

月次のテーブルは実数（`seasonally_adjusted = false`）と季節調整値（`true`）が同じ列に並びます。
月どうしを比べるときは季節調整値、都道府県の求人数を足すときは実数を使います。
1972年までの全国の値は沖縄県を含みません。

```sql
-- 有効求人倍率（季節調整値、受理地別）の最新の月を都道府県で比べる
SELECT area_name, active_openings_ratio
FROM e_stat.job_placement.labor_market_monthly
WHERE basis = '受理地' AND seasonally_adjusted AND prefecture_code IS NOT NULL
    AND (year, month) = (SELECT max((year, month)) FROM e_stat.job_placement.labor_market_monthly)
ORDER BY active_openings_ratio DESC;
```

年・年度のテーブルの求人数・求職者数は月平均の値です。1年間の合計ではありません。
