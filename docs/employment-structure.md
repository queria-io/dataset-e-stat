---
title: 有業率と非正規の割合（就業構造基本調査）
order: 26
---

# 就業構造基本調査（employment_status）

就業状態・従業上の地位・雇用形態別の15歳以上人口を、地域・男女・配偶関係・教育・年齢階級ごとに収録します。テーブルは `e_stat.employment_structure.employment_status`。調査は5年ごとで、2017年と2022年の2回分、114,480行です。有業率（有業者 ÷ 15歳以上人口）と非正規の割合（非正規 ÷ (正規 + 非正規)）を都道府県や大きな市で比べられます。

出典: [総務省統計局 就業構造基本調査](https://www.stat.go.jp/data/shugyou/)

## カラム構成

- year: 調査年（2017 / 2022）
- area / area_name / area_kind: 地域コード / 地域名 / 地域の段（`national` / `prefecture` / `urban_part` / `city`）
- prefecture_code: 都道府県コード（2桁）
- sex_code / sex: 男女（`0` 総数・`1` 男・`2` 女）
- marital_status_code / marital_status: 配偶関係（`0` 総数・`1` うち未婚）
- education_code / education: 教育（`0` 総数・`1` 卒業者・`2` 在学者。在学者は2022年のみ）
- status_code / status / status_level / status_parent: 就業状態・従業上の地位・雇用形態
- age_class_code / age_class: 年齢階級（`0` 総数・`1` 15〜34歳・`2` 35〜54歳・`3` 55〜74歳・`4` 75歳以上）
- unit / value: 単位（人） / 人数

## 都道府県で並べる

```sql
SELECT area_name,
    round(100.0 * MAX(value) FILTER (WHERE status_code = '112')
        / (MAX(value) FILTER (WHERE status_code = '111') + MAX(value) FILTER (WHERE status_code = '112')), 1) AS non_regular_pct
FROM e_stat.employment_structure.employment_status
WHERE year = 2022 AND area_kind = 'prefecture'
  AND sex_code = '0' AND marital_status_code = '0' AND education_code = '0' AND age_class_code = '0'
GROUP BY area_name
ORDER BY non_regular_pct DESC
```

2022年の非正規の割合は京都府が40.7%で最も高く、奈良県40.6%、滋賀県40.2%と続きます。最も低いのは富山県の32.3%です。全国は36.9%で、2017年の38.2%から下がりました。

## 5年の変化を見る

```sql
SELECT area_name, year,
    round(100.0 * MAX(value) FILTER (WHERE status_code = '1') / MAX(value) FILTER (WHERE status_code = '0'), 1) AS employment_rate
FROM e_stat.employment_structure.employment_status
WHERE area_kind IN ('national', 'prefecture')
  AND sex_code = '2' AND marital_status_code = '0' AND education_code = '0' AND age_class_code = '2'
GROUP BY area_name, year
ORDER BY area_name, year
```

35〜54歳の女性の有業率は、全国で2017年の76.2%から2022年の79.8%に上がりました。

## 就業状態は「うち」の入れ子

`status_code` は内訳ではなく「うち」の行です。`0` 総数 ⊃ `1` うち有業者 ⊃ `11` うち雇用者 ⊃ `111` うち正規 / `112` うち非正規 ⊃ `1121` うちパート・アルバイト。足し上げると何重にも数えます。雇用者には会社などの役員を含むので、正規と非正規の合計は雇用者より少なくなります。

## 地域の並びは年で違う

2017年は全国・都道府県とその市部・政令指定都市と東京特別区部の21市、2022年は全国・都道府県と、政令指定都市・県庁所在都市・人口30万以上の86市です。市区町村すべては無く、市を年をまたいで比べられるのは2017年にも載る21市だけです。都道府県の行は市部と市を含むので、`area_kind` をそろえて比べます。

## 標本調査の推定値

値は百人単位に丸めた推定値で、男女や年齢階級を足すと総数と最大100〜200人ずれます。原典で「-」（該当数値なし）のセルは NULL です。市や細かい区分ほど標本が小さく、値が NULL になるセルも多くなります。
