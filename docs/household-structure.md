---
title: 全国家計構造調査 年間収入階級別の消費支出
order: 45
---

# 全国家計構造調査 年間収入階級別の消費支出

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| income_class_expenditure | 総世帯の1世帯当たり1か月間の消費支出と10大費目を、年間収入階級（44区分）で分けた表。全国。2019年 | income_class_code / income_class / income_lower / income_upper / is_reclassified / item_code / item_name / expenditure / households / household_members |

2019年全国家計構造調査 家計総合集計の統計表 0003424577 のうち、総世帯・全世帯・世帯主の性別平均の行です。
年間収入階級ごとに、世帯数分布（抽出率調整後の推計世帯数）と世帯人員などを列に持ちます。
世帯数分布は比率ではなく世帯の数で、平均（00）の行が全体の 51,229,953世帯、01〜40 の和（51,229,954世帯）と1世帯の差で一致します。

```sql
-- 年間収入階級別の消費支出と食料の割合
SELECT income_class, income_lower, income_upper,
    max(expenditure) FILTER (WHERE item_code = '2101') AS consumption,
    round(100.0 * max(expenditure) FILTER (WHERE item_code = '210101')
        / max(expenditure) FILTER (WHERE item_code = '2101'), 1) AS food_pct
FROM e_stat.household_structure.income_class_expenditure
WHERE NOT is_reclassified AND income_class_code <> '00'
GROUP BY income_class_code, income_class, income_lower, income_upper
ORDER BY income_class_code;
```

## 平均・再掲と内訳が同じ列に並ぶ

年間収入階級は平均（00）、40区分（01〜40）、再掲（R1〜R3）が同じ列にあります。収入階級を足し上げるときは
`NOT is_reclassified AND income_class_code <> '00'` で40区分に絞ります。収支項目も消費支出（2101）と
10大費目（210101〜210110）が同じ列にあるので、絞らずに足すと二重に数えます。households などの付帯値は
11項目の行に同じ値が入るので、世帯数を足すときは item_code を1つに絞ります。

出典: 総務省統計局 2019年全国家計構造調査。
https://www.e-stat.go.jp/dbview?sid=0003424577

## 補足: household_structure.income_class_expenditure

全国の値で、都道府県別の行は無い。
縦持ちで、44区分 × 11項目（消費支出と10大費目）の484行。
世帯区分は全世帯、世帯主の性別は平均。
年間収入階級（income_class_code）は 00 平均、01 100万円未満、02〜39 は100万円から2000万円まで50万円刻み、40 2000万円以上の40区分と、R1〜R3 の再掲（1000〜1250万円、1250〜1500万円、1500万円以上）。
再掲は 01〜40 の一部を束ねたものなので、収入階級を足し上げるときはis_reclassified が false の 01〜40 だけを使う。
収支項目（item_code）は 2101 消費支出と、その内訳の10大費目（210101 食料 〜 210110 その他の消費支出）。
10大費目の和と消費支出は円未満の丸めで最大2円ずれる。
同じ収入階級の付帯値（集計世帯数・世帯数分布・世帯人員・18歳未満人員・65歳以上人員・有業人員・世帯主の年齢）を列に持つ。
この値は収入階級ごとに1つで、11項目の行に同じ値が入る。
世帯数分布（households）は抽出率で調整した推計世帯数で、比率ではなく世帯の数。
01〜40 の消費支出をhouseholds で加重平均すると平均（00）の消費支出に一致する。
2019年の総世帯の消費支出は平均で月 237,091円。
収入階級別では 100万円未満の 104,417円から、1900〜1950万円の 586,217円まで。
