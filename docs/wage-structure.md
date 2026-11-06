---
title: 都道府県・産業別の賃金（賃金構造基本統計調査）
order: 27
---

# 賃金構造基本統計調査（prefecture_wage / prefecture_industry_wage）

一般労働者（短時間労働者以外の常用労働者）の賃金を都道府県別に収録します。テーブルは2つです。

- `e_stat.wage_structure.prefecture_wage`: 都道府県別・男女別の所定内給与額・きまって支給する現金給与額・年間賞与その他特別給与額・平均年齢・勤続年数・労働時間・労働者数。864行
- `e_stat.wage_structure.prefecture_industry_wage`: 都道府県別・産業（大分類16区分）別・男女別の所定内給与額と年間賞与その他特別給与額。13,824行

収録は2020〜2025年調査です。企業規模計（10人以上）の値で、金額は千円単位の平均値です。

出典: [厚生労働省 賃金構造基本統計調査](https://www.e-stat.go.jp/stat-search/files?toukei=00450091)

## カラム構成

- year: 調査年（2020〜2025）
- area / area_name / prefecture_code: 地域コード（`00000` 全国・`XX000` 都道府県） / 地域名 / 都道府県コード（全国は NULL）
- sex_code / sex: 男女（`0` 男女計・`1` 男・`2` 女）
- industry_code / industry: 産業（prefecture_industry_wage のみ。大分類 C〜R）
- scheduled_earnings: 所定内給与額（千円、6月分の月額。残業代などを含まない）
- contractual_earnings: きまって支給する現金給与額（千円、6月分の月額。prefecture_wage のみ）
- annual_special_earnings: 年間賞与その他特別給与額（千円、調査前年1年間の合計）
- age / tenure_years / scheduled_hours / overtime_hours / workers: 平均年齢 / 平均勤続年数 / 所定内・超過実労働時間数 / 労働者数（人）。prefecture_wage のみ

## 都道府県で並べる

```sql
SELECT area_name, scheduled_earnings, annual_special_earnings
FROM e_stat.wage_structure.prefecture_wage
WHERE year = 2025 AND sex_code = '0' AND area <> '00000'
ORDER BY scheduled_earnings DESC
```

2025年の所定内給与額は東京都が418.3千円で最も高く、神奈川県368.6千円、大阪府348.9千円と続きます。最も低いのは青森県の263.9千円です。全国は2020年の307.7千円から2025年の340.6千円に上がりました。

## 産業を産業計と比べる

prefecture_industry_wage に産業計の行は無いので、prefecture_wage と結合します。

```sql
SELECT i.area_name, i.scheduled_earnings AS medical_welfare, p.scheduled_earnings AS all_industries,
    round(100.0 * i.scheduled_earnings / p.scheduled_earnings, 1) AS ratio_pct
FROM e_stat.wage_structure.prefecture_industry_wage i
JOIN e_stat.wage_structure.prefecture_wage p USING (year, area, sex_code)
WHERE i.year = 2025 AND i.sex_code = '0' AND i.industry_code = 'P' AND i.area <> '00000'
ORDER BY ratio_pct DESC
```

医療，福祉の所定内給与額は、秋田県では産業計の109.7%、東京都では88.4%です。

## 月額と年額が混ざっている

所定内給与額ときまって支給する現金給与額は調査年の6月分の月額、年間賞与その他特別給与額は調査前年1年間の合計です。

## 2019年以前とは比べない

2020年調査で一部の調査事項と推計方法が変わり、厚生労働省はそれまでの公表値との比較には注意が必要としています。収録は2020年からです。

## 労働者数と欠けているセル

workers は原典の十人単位を10倍した推計値で、男と女の合計は男女計と最大10人、47都道府県の合計は全国と最大50人ずれます。prefecture_industry_wage で原典が「-」のセルは NULL で、鉱業，採石業，砂利採取業（C）の41行だけです。

## 補足: 賃金構造基本統計調査 都道府県別・産業別の賃金（wage_structure スキーマ）

厚生労働省の賃金構造基本統計調査のうち、一般労働者（短時間労働者以外の常用労働者）の
都道府県別の参考表2つです。企業規模計（10人以上）の値で、金額は千円単位の平均値です。
prefecture_wage は864行（全国+47都道府県 × 男女計・男・女 × 6年）、
prefecture_industry_wage は13,824行（さらに × 16産業）です。

#### 産業別の表に産業計は無い

prefecture_industry_wage の産業は日本標準産業分類の大分類 C〜R の16区分で、産業計の行は
ありません。産業計と比べるときは prefecture_wage の同じ年・地域・性の行と結合します。

秋田県は109.7%で産業計を上回り、東京都は88.4%で最も低くなります。

## 補足: wage_structure.prefecture_industry_wage

賃金構造基本統計調査の一般労働者の所定内給与額と年間賞与その他特別給与額を、都道府県別・産業（大分類）別・男女別に収録する（都道府県別 参考表2）。
収録は2020年〜2025年調査の6年、13,824行（全国+47都道府県 × 16産業 × 男女計・男・女 × 6年）。
2025年の全国の所定内給与額は、電気・ガス・熱供給・水道業 444.0千円が最も高く、宿泊業，飲食サービス業 277.2千円が最も低い。
鉱業，採石業，砂利採取業（C）の41行だけで、所定内給与額と年間賞与は常に同じ行で欠ける。

## 補足: wage_structure.prefecture_wage

賃金構造基本統計調査の一般労働者の賃金を、都道府県別・男女別に収録する（都道府県別 参考表1）。
所定内給与額・きまって支給する現金給与額・年間賞与その他特別給与額のほか、平均年齢・勤続年数・実労働時間数・労働者数が1行に並ぶ。
調査は毎年6月分の賃金で、年間賞与は前年1年間の支給額。
2025年の所定内給与額は全国 340.6千円で、東京都 418.3千円が最も高く、青森県 263.9千円が最も低い。
短時間労働者の時給はこの表に無い。
労働者数は推計値で、原典の十人単位を10倍して人に直してある。
