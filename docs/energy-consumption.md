---
title: 都道府県別のエネルギー消費量（エネルギー消費統計調査）
order: 54
---

# エネルギー消費統計調査（energy_consumption）

資源エネルギー庁のエネルギー消費統計調査から、都道府県別のエネルギー消費量を業種別とエネルギー種別の2通りに収録します。値は熱量（TJ、テラジュール）です。

- `e_stat.energy_consumption.prefecture_industry`: 都道府県 × 業種（46）。35,328行
- `e_stat.energy_consumption.prefecture_energy_type`: 都道府県 × エネルギー種別（37）。28,416行

収録は2009〜2024年度です。

出典: [資源エネルギー庁 エネルギー消費統計調査](https://www.e-stat.go.jp/stat-search/files?toukei=00551005)（石油等消費動態統計を含まない結果の参考1・参考2、熱量単位表）

## 対象の範囲

事業所の調査なので、家庭の消費は含みません。製造業は、石油等消費動態統計調査の対象の事業所の分を含みません。日本全体のエネルギー消費量（総合エネルギー統計など）とは範囲が違います。

## カラム構成

- fiscal_year: 年度（2009〜2024）
- area / area_name / prefecture_code: 地域コード（`00000` 全国・`XX000` 都道府県） / 地域名 / 都道府県コード（全国は NULL）
- industry_code / industry_name / parent_industry_code（prefecture_industry）: 業種の記号・名前・1つ上の業種の記号
- energy_type / parent_energy_type（prefecture_energy_type）: エネルギー種別と1つ上の種別
- energy_tj: エネルギー消費量（TJ）

## 計の行と内訳

どちらのテーブルも、計の行が内訳と同じ列に並びます。`parent_*` が1つ上の行を指し、同じ親の行を足すと親の値に一致します。

- 業種: 業種計 `A~S` = 非製造業計 `A~D`（A〜D）+ 製造業 `E`（中分類 9〜32）+ 業務部門計 `F~S`（F〜S）
- エネルギー種別: 合計 = 燃料 + 電力 + 熱。燃料 = 非石油系燃料（石炭・都市ガスなど）+ 石油系燃料（灯油・A重油など）、電力 = 買電 + 自家発電、熱 = 蒸気 + 温水・冷水

全国の行も都道府県の行と並びます。47都道府県の合計は全国の行に一致し、業種計とエネルギー種別の合計も一致します。

## 業務部門の割合を都道府県で並べる

```sql
SELECT area_name,
    round(sum(energy_tj) FILTER (WHERE industry_code = 'F~S')) AS commercial_tj,
    round(100 * sum(energy_tj) FILTER (WHERE industry_code = 'F~S')
        / sum(energy_tj) FILTER (WHERE industry_code = 'A~S'), 1) AS commercial_pct
FROM e_stat.energy_consumption.prefecture_industry
WHERE fiscal_year = 2024 AND area <> '00000'
GROUP BY area_name
ORDER BY commercial_pct DESC
```

2024年度は沖縄県（77.3%）と東京都（75.3%）で業務部門（卸売・小売、宿泊・飲食、医療・福祉など）の割合が高く、静岡県（46.5%）・三重県（48.0%）・富山県（48.4%）で低くなっています。

## 燃料・電力・熱の割合を比べる

```sql
SELECT area_name, energy_type,
    round(100 * energy_tj / sum(energy_tj) OVER (PARTITION BY area), 1) AS share_pct
FROM e_stat.energy_consumption.prefecture_energy_type
WHERE fiscal_year = 2024 AND parent_energy_type = '合計'
ORDER BY area, energy_type
```

2024年度の全国は電力57.2%・燃料35.1%・熱7.7%で、東京都は電力が63.1%、北海道は燃料が40.3%です。

## 更新

この2表は毎日の更新（CI）では取らず、手元で1回だけ取り込んでいます（`local_tables.yml` の `energy_consumption`）。新しい年度のファイルが出ると、Check updates のワークフローが issue を立てます。
