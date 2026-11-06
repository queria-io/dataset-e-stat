---
title: 民間給与実態統計調査 業種別・給与階級別の給与所得者数と給与
order: 43
---

# 民間給与実態統計調査 業種別・給与階級別の給与所得者数と給与

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| industry_salary_class | 1年を通じて勤務した給与所得者の人数・平均年齢・給与。業種別・給与階級別・男女別。全国。2014〜2024年分 | year / industry_code / industry / salary_class_code / salary_class / salary_class_lower / salary_class_upper / sex_code / sex / earners / avg_age / avg_tenure_years / wages_avg / bonus_avg / pay_total / pay_avg |

国税庁の民間給与実態統計調査のうち、全国計表 第9表（業種別及び給与階級別の給与所得者数・給与額）です。
7,425行（15業種区分 × 15給与階級区分 × 3性別区分 × 11年）で、給与階級別の人数を持つので
平均だけでなく年間給与の分布が見られます。都道府県別の行はありません。

```sql
-- 年間給与が1,000万円を超える人と300万円以下の人の割合（全業種、2014年と2024年）
SELECT year, sex,
    round(100.0 * sum(earners) FILTER (WHERE salary_class_lower >= 1000)
        / max(earners) FILTER (WHERE salary_class_code = '15'), 1) AS over_10m_pct,
    round(100.0 * sum(earners) FILTER (WHERE salary_class_upper <= 300)
        / max(earners) FILTER (WHERE salary_class_code = '15'), 1) AS under_3m_pct
FROM e_stat.private_salary.industry_salary_class
WHERE industry_code = '15' AND year IN (2014, 2024)
GROUP BY year, sex_code, sex
ORDER BY year, sex_code;
```

2024年分は1,000万円超が6.2%（男9.8%、女1.6%）、300万円以下が31.9%（男17.9%、女50.6%）です。
2014年分はそれぞれ4.5%と40.1%でした。

```sql
-- 業種別の平均給与（2024年分、男女計）
SELECT industry, pay_avg, wages_avg, bonus_avg, earners
FROM e_stat.private_salary.industry_salary_class
WHERE year = 2024 AND salary_class_code = '15' AND sex_code = '3' AND industry_code <> '15'
ORDER BY pay_avg DESC;
```

電気･ガス･熱供給・水道業が8,324千円で最も高く、宿泊業，飲食サービス業の2,793千円が最も低くなります。
全業種の平均給与は4,775千円です。

## 計と内訳が同じ列に並ぶ

業種の合計（industry_code = '15'）、給与階級の計（salary_class_code = '15'）、性別の計（sex_code = '3'）が
内訳と同じ列にあります。足すときはどの軸も計か内訳のどちらかに絞ります。
人数は標本からの推計値なので、内訳の合計と計は最大4人ずれます。

## 給与階級は上限の名前で区間を表す

給与階級の名前は「200万円以下」のように上限だけですが、実際は前の階級の上限を超えこの上限以下の区間です。
salary_class_lower と salary_class_upper に区間の両端を万円で持たせています。
1,000万円までは100万円刻み、その上は1,500万円・2,000万円・2,500万円で区切り、最後が2,500万円超です。

## 業種は国税庁の区分

業種は国税庁の14区分で、日本標準産業分類の大分類とは区切りが違います。学術研究，専門・技術サービス業と
教育，学習支援業が1区分、農林水産業と鉱業が1区分にまとまっています。wage_structure の産業とは
そのまま対応しません。

## 欠けているセル

原典の「-」（該当する計数のないとき）は NULL です。給与所得者のいない66行は全指標が NULL で、
ほかに賞与だけが NULL の行が67行あります。賞与が NULL の行は給与が給料・手当と同じ値です。

## 2013年以前の系列は取らない

e-Stat には2008年からの同名の統計表（0003045946）もありますが、重なる2014〜2021年でも
セルの95%で値が違います。収録はこの表の2014年からの系列だけです。

出典: 国税庁 民間給与実態統計調査。
https://www.e-stat.go.jp/stat-search/database?statdisp_id=0004009620

## 補足: private_salary.industry_salary_class

民間給与実態統計調査の、1年を通じて勤務した給与所得者の人数と給与を、業種別・給与階級別・男女別に収録する（全国計表 第9表）。
全国の値で、都道府県別の行は無い。
給与階級（salary_class_code）は100万円刻みで1,000万円まで、その上は500万円刻みで2,500万円超まで。
2024年の平均給与（pay_avg）は合計で4,775千円。
人数が最も多い給与階級は300万円超400万円以下（16.1%）。
原典で「-」（該当する計数のないとき）のセルは NULL。
この表は2014年からの系列だけを収録する。
https://www.e-stat.go.jp/stat-search/database?statdisp_id=0004009620国税庁ポータル: https://www.nta.go.jp/publication/statistics/kokuzeicho/minkan/toukei.htm
