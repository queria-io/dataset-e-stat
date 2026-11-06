---
title: 労働力調査 就業状態別人口・完全失業率
order: 35
---

# 労働力調査 就業状態別人口・完全失業率

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| labor_force | 就業状態別15歳以上人口（万人）。全国の月次と地域ブロック別の四半期 | frequency / industry_code / sex_code / labor_status_code / labor_status / labor_status_level / age_class_code / area / year / month / quarter / unit / value |
| labor_force_rate | 労働力人口比率・就業率・完全失業率（％）。粒度は labor_force と同じ | frequency / sex_code / indicator_code / indicator / age_class_code / area / year / month / quarter / unit / value |

労働力調査 基本集計です。全国は月次で1968年1月から、地域ブロック別は四半期で
2000年1〜3月期から収録しています。都道府県別はありません。標本設計が地域ブロックまでなので、
都道府県別の有業者数や非正規の割合は `employment_structure` スキーマ（就業構造基本調査）にあります。
都道府県別の完全失業率は県別の推計を使います。

社会・人口統計体系の `ssds.pref_labor` / `ssds.municipal_labor`（F 労働）とは別物です。
あちらは各種統計から集めた労働分野の指標で、労働力調査の原表ではありません。

## 単位は万人

`value` の単位は人ではなく万人です。`unit` にも「万人」と入っています。
値は万人単位で丸められているので、内訳を足しても総数と数万人ずれます。

## 全国の月次と地域ブロックの四半期

月次と四半期を1つの表に積んであります。時間軸コードが衝突しない（月次は 2024000404、
四半期は 2024000406）ので、`frequency` で絞ります。

月次にあるのは全国だけ、地域ブロックがあるのは四半期だけです。ただし四半期にも全国の行が
あるので、同じ期間を月次と四半期の両方が持ちます。絞らずに合計すると二重に数えます。

`area` には全国（`00000`）が地域ブロックと同じ列に入っています。地域を足し上げるときは
除きます。九州は2011年10〜12月期までが九州・沖縄地方（`00055`）、2012年1〜3月期以降が
九州地方（`00057`）と沖縄地方（`00059`）に分かれます。同じ時点に両方が並ぶことはありません。

```sql
-- 地域ブロック別の完全失業率（2026年4〜6月期）
SELECT area_name, value
FROM e_stat.labor.labor_force_rate
WHERE indicator = '完全失業率' AND frequency = '四半期'
  AND area <> '00000' AND sex_code = '0' AND age_class_code = '00'
  AND time = '2026000406'
ORDER BY value DESC;
```

## 就業状態の階層

15歳以上人口・労働力人口・就業者・完全失業者・非労働力人口が同じ列に縦に並びます。
深さは `labor_status_level` に出ていますが、level = 1 は入れ子の総数を含みます
（15歳以上人口 ⊃ 労働力人口 ⊃ 就業者 ⊃ 従業者）。足し上げても総数にはなりません。

成り立つのは次の2つです。

- 労働力人口（`01`）= 就業者（`02`）+ 完全失業者（`08`）
- 就業者（`02`）= 従業者（`03`）+ 休業者（`07`）

15歳以上人口（`00`）は労働力人口と非労働力人口（`09`）の合計より数万人多くなります
（実測で最大13万人）。差はこの表に区分の無い就業状態不詳の分で、この恒等式は成り立ちません。

## 年齢階級

`age_class_level` = 1 には総数の「15歳以上」と再集計の「15〜64歳」が各階級と同居しています。
level で絞っただけでは区分になりません。全国の月次は30区分、地域ブロックの四半期は
その部分集合の18区分です。総数は `age_class_code = '00'` です。

性別（`sex_code`）も 0 = 総数、1 = 男、2 = 女 で総数と内訳が同じ列にあります。

```sql
-- 男女別の就業率（2024年・全国・月次の平均）
SELECT sex, round(avg(value), 1) AS employment_rate
FROM e_stat.labor.labor_force_rate
WHERE indicator = '就業率' AND frequency = '月次'
  AND area = '00000' AND age_class_code = '00' AND year = 2024
GROUP BY sex, sex_code
ORDER BY sex_code;
```

## 産業の内訳がある状態

`industry_code` は全産業（`000`）・農業，林業（`001`）・非農林業（`004`）の3区分です。
内訳を持つのは就業者・従業者・休業者など就業者系の状態だけで、15歳以上人口・労働力人口・
完全失業者・非労働力人口には全産業の行しかありません。産業を絞らずに集計すると、
就業者だけが3重になります。地域ブロックの四半期は産業を分けない集計なので、
一律 `000` が入っています。

産業中分類までの内訳は同じ調査の別表にあり、この2テーブルには入っていません。

## 完全失業率の分母

`labor_force_rate` の3指標は分母が違います。労働力人口比率と就業率は15歳以上人口が分母、
完全失業率だけは労働力人口が分母です。3指標を足しても意味を持ちません。

e-Stat のメタ情報は3指標の名称を「労働力人口」「就業」「完全失業者」としていて人数の表と
同じ名前になるため、`indicator` では指標名に置き換えています。元のコードは
`indicator_code`（`01` / `13` / `08`）に残しています。

値は小数第1位で丸められています。`labor_force` の実数から計算し直すと0.1ポイント程度ずれます。

```sql
-- 完全失業率の推移（2024年・全国・月次）
SELECT time_name, value AS unemployment_rate
FROM e_stat.labor.labor_force_rate
WHERE indicator = '完全失業率' AND frequency = '月次'
  AND area = '00000' AND sex_code = '0' AND age_class_code = '00' AND year = 2024
ORDER BY month;
```

出典: 総務省統計局 労働力調査 基本集計。
https://www.stat.go.jp/data/roudou/

## 補足: labor.labor_force

全国の月次（1968年1月〜）と地域ブロック別の四半期（2000年1〜3月期〜）を1つの表に積んである。
月次には全国しか無く、地域ブロックがあるのは四半期だけなので、frequency で絞らないと粒度が混ざる。
都道府県別はこの調査には無い（標本設計が地域ブロックまで）。
全国・月次 https://www.e-stat.go.jp/dbview?sid=0002060002地域別・四半期 https://www.e-stat.go.jp/dbview?sid=0003009572統計局ポータル: https://www.stat.go.jp/data/roudou/

## 補足: labor.labor_force_rate

全国の月次（1968年1月〜）と地域ブロック別の四半期（2000年1〜3月期〜）を1つの表に積んである。
分母は指標ごとに違う。
月次には全国しか無く、地域ブロックがあるのは四半期だけなので、frequency で絞らないと粒度が混ざる。
都道府県別はこの調査には無い。
全国・月次 https://www.e-stat.go.jp/dbview?sid=0002060004地域別・四半期 https://www.e-stat.go.jp/dbview?sid=0003009576統計局ポータル: https://www.stat.go.jp/data/roudou/
