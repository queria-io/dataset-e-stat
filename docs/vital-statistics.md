---
title: 市区町村別の出生・死亡・死因（人口動態調査）
order: 32
---

# 人口動態調査（vital_statistics）

出生・死亡・死産・婚姻・離婚の数を、都道府県・市区町村ごとに年で収録します。出生は母の年齢別、死亡は年齢別と死因別にも見られます。

- `e_stat.vital_statistics.vital_events`: 出生・低体重児の出生・死亡・乳児死亡・新生児死亡・死産・周産期死亡・婚姻・離婚（19,628行）
- `e_stat.vital_statistics.births_by_mother_age`: 母の年齢（5歳階級）別の出生数（194,280行）
- `e_stat.vital_statistics.deaths_by_age`: 年齢（5歳階級）別の死亡数（428,076行）
- `e_stat.vital_statistics.deaths_by_cause`: 死因（選択死因分類）別の死亡数（719,946行）

収録は2015〜2024年です。日本にいる日本人の出生・死亡などを、住所のある地域で数えます。

出典: [厚生労働省 人口動態調査](https://www.e-stat.go.jp/statistics/00450011)

## ほかの表との違い

[SSDS の市区町村の表](/cookbook/e_stat/a-population)にも出生数・死亡数・婚姻件数・離婚件数がありますが、2023年までです。乳児死亡や死産、年齢別・死因別の死亡数はありません。住民基本台帳（`resident_registry`）の出生・死亡は外国人を含む届出の数で、この表とは数え方が違います。

## カラム構成

4表に共通の列です。

- year: 年（2015〜2024）
- area_code / area_name: 標準地域コード（5桁） / 地域名
- area_kind: 地域の粒度（下の「地域の粒度」）
- prefecture_code: 都道府県コード（全国・外国・不詳は NULL）

vital_events は births（出生数）・deaths（死亡数）・infant_deaths（乳児死亡数）・marriages（婚姻件数）などを1行に持ちます。ほかの3表は区分の列（mother_age_class・age_class・cause_name など）と、男女別の数（births_male・deaths_female など）を持ちます。

## 札幌市の出生数と死亡数

```sql
SELECT year, births, deaths, marriages
FROM e_stat.vital_statistics.vital_events
WHERE area_code = '01100'
ORDER BY year
```

札幌市の出生数は2015年の14,589人から2024年の9,586人へ減り、死亡数は17,523人から24,576人へ増えています。

## 地域の粒度

`area_kind` で粒度を見分けます。絞らずに合計すると同じ人を何度も数えます。

vital_events:

- `prefecture`（都道府県）だけで日本全域を1回覆います
- `municipality`（政令指定都市以外の市町村と東京都の特別区）と `designated_city`（政令指定都市）の組でも1回覆います
- `ward`（政令指定都市の区）は `designated_city` の内訳です

births_by_mother_age・deaths_by_age・deaths_by_cause:

- 政令指定都市そのものの行はありません。日本全域を1回覆うのは `prefecture` か、`municipality` と `ward` の組です
- 死亡の2表は `nationwide`（全国）・`foreign`（住所が外国）・`unknown`（住所が不詳）の行も持ち、全国は都道府県・外国・不詳の和です。出生の表は全国の行を持たないので、都道府県を足します

`area_code` は各年のコードのままです。たとえば富谷市は2015年が富谷町（04423）、2016年からが富谷市（04216）です。浜松市の区は2024年の再編で 22138〜22140 になりました。

## 死因の段

`deaths_by_cause` は総数（`cause_level = 'total'`）・死因（`cause`）・その内訳（`subcause`、悪性新生物の部位など）・再掲（`restatement`）が同じ列に並びます。選択死因分類は主な死因だけを選んだ分類なので、`cause` を足しても総数にはなりません。

```sql
SELECT cause_name, deaths, deaths_male, deaths_female
FROM e_stat.vital_statistics.deaths_by_cause
WHERE year = 2024 AND area_kind = 'nationwide' AND cause_level = 'cause'
ORDER BY deaths DESC
LIMIT 5
```

悪性新生物と高血圧性疾患は2017年から分類が変わりました。2016年までは `Se02`・`Se15`、2017年からは `Se022017`・`Se152017` の行です。年で続けて見るときは2つのコードをつなぎます。

## 0 と NULL

原典の「-」（該当なし）は 0 です。男の子宮の悪性新生物（`Se12`）だけは原典が「・」（あり得ない項目）なので、`deaths_male` が NULL です。
