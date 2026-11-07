---
title: 経済産業省企業活動基本調査 産業別・都道府県別・資本金規模別の財務、研究開発、外資系企業、子会社
order: 49
---

# 経済産業省企業活動基本調査 産業別・都道府県別・資本金規模別の財務、研究開発、外資系企業、子会社

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| industry_finance | 産業別の企業数・事業所数・従業者数・資産・負債及び純資産・売上高・利益・付加価値額・子会社数（2015〜2024年度） | fiscal_year / industry_code / measure / unit / value |
| prefecture_finance | 都道府県別・産業別の同じ項目（2019〜2024年度） | fiscal_year / industry_code / area / measure / unit / value |
| capital_size_finance | 資本金規模別・産業別の資産・負債及び純資産・損益・費用の内訳（2019〜2024年度） | fiscal_year / industry_code / capital_size_code / measure / unit / value |
| research_development | 産業別の研究開発費・受託研究費・研究開発投資・能力開発費（2019〜2024年度） | fiscal_year / industry_code / measure / unit / value |
| foreign_affiliated_finance | 外資系企業の産業別の企業数・財務（2019〜2024年度） | fiscal_year / industry_code / measure / unit / value |
| subsidiary_count | 親会社の産業別・子会社の業種別の子会社・関連会社数（議決権所有割合別、国内・海外別）（2019〜2024年度） | fiscal_year / industry_code / subsidiary_industry_code / measure / unit / value |

経済産業省の企業活動基本調査（確報）です。従業者50人以上かつ資本金または出資金3,000万円以上の、
鉱業、製造業、卸売業、小売業、一部のサービス業などの企業を対象に、毎年、前年度の実績を調べます。
2020〜2025年の調査（2019〜2024年度実績）の表を収録しています。総括表（industry_finance）は
各調査が過去5年度の値も持つので、2015年度からあります。同じ年度は最も新しい調査の値を使います。

## 産業と測定項目

`industry_code` には、総合計・合計・大分類・中分類・小分類が同じ列に並びます。企業数では次の関係が
ちょうど成り立ちます。

- 合計（`000`）= 大分類（`C`・`E`・`F`・`G`・`I1`・`I2`・`J1`・`K1`・`L`・`M`・`N`・`O`・`R1`）の和
- 総合計 = 合計（`000`）+ サービス業（その他のサービス業）（`R2`）+ その他の産業（`Z`）

`measure` は「資産_流動資産」のように上位の項目と「_」でつないだ名称で、計と内訳が同じ列に並びます。
単位は `unit` にあり、表によって社・事業所・人・百万円・％が混ざります。

```sql
-- 2024年度 大分類別の売上高
SELECT industry_code, industry_name, round(value / 1e6, 1) AS sales_trillion_yen
FROM e_stat.enterprise_activity.industry_finance
WHERE fiscal_year = 2024 AND measure = '売上高'
  AND industry_code IN ('C', 'E', 'F', 'G', 'I1', 'I2', 'J1', 'K1', 'L', 'M', 'N', 'O', 'R1')
ORDER BY value DESC;
```

## 都道府県別

prefecture_finance は企業を本社のある都道府県に数えた値です。47都道府県の企業数と事業所数の和は
全国に一致します。売上高などは秘匿の分だけ和が全国より小さくなる年度があります。

## 資本金規模別

capital_size_finance は第3-1表（資産・負債及び純資産）と第4表（損益・費用の内訳）を積んだものです。
企業数・売上高・経常利益は両方の表にあるので、第3-1表の値だけを残しています。資本金規模は計（`00`）と
8区分で、企業数では8区分の和が計に一致します。

## 研究開発

research_development の企業数（`研究開発_企業数` など）は研究開発・研究開発投資・能力開発を行った
企業の数です。産業の企業数全体ではありません。
