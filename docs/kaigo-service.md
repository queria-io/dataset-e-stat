---
title: 介護保険施設の施設数・定員
order: 25
---

# 介護サービス施設・事業所調査（insurance_facility）

介護老人福祉施設（特別養護老人ホーム）・介護老人保健施設・介護医療院・介護療養型医療施設の施設数と定員を、市区町村別・施設の種類別に収録します。テーブルは `e_stat.kaigo_service.insurance_facility`。2001年から2024年までの534,444行で、調査日は毎年10月1日です。

出典: [厚生労働省 介護サービス施設・事業所調査](https://www.e-stat.go.jp/stat-search/files?toukei=00450042)

## カラム構成

1セル1行の縦持ちです。指標を `measure` で選び、地域と施設の種類で絞ります。

- survey_year: 調査年
- area_code / area_name / area_kind: 標準地域コード / 地域名 / 集計の段
- prefecture_code / prefecture_name: 都道府県コード / 都道府県名
- facility_type: 施設の種類
- survey_form: 調査票（`基本票` / `詳細票`）
- measure: 指標（`facility_count` / `capacity` / `fte_workers`）
- value: 値

## 市区町村で並べる

```sql
SELECT area_name, prefecture_name, value AS capacity
FROM e_stat.kaigo_service.insurance_facility
WHERE survey_year = 2024
  AND facility_type = '介護老人福祉施設'
  AND measure = 'capacity'
  AND area_kind IN ('municipality', 'designated_city')
ORDER BY value DESC
LIMIT 10
```

2024年の介護老人福祉施設の定員は横浜市が18,037人で最も多く、大阪市13,715人、名古屋市8,439人と続きます。全国1,741市区町村のうち、介護保険施設が1つも無いのは86です。

## 行政区の行を足すと二重に数える

政令指定都市は市の合計行（`designated_city`）と行政区の行（`ward`）が両方並びます。足し合わせて全国になるのは `municipality` と `designated_city` だけです。

```sql
-- 市区町村を足すと全国の行と一致する
SELECT
    SUM(value) FILTER (WHERE area_kind = 'nationwide') AS nationwide,
    SUM(value) FILTER (WHERE area_kind IN ('municipality', 'designated_city')) AS summed,
    SUM(value) FILTER (WHERE area_kind IN ('municipality', 'designated_city', 'ward')) AS with_wards
FROM e_stat.kaigo_service.insurance_facility
WHERE survey_year = 2024
  AND facility_type = '介護老人福祉施設'
  AND measure = 'capacity'
```

2024年の介護老人福祉施設の定員は、全国の行も市区町村の合計も604,469人です。行政区を混ぜると724,785人になります。

東京23区は基礎自治体なので `municipality` です。同じ「区」でも政令指定都市の行政区とは扱いが逆になります。2004年〜2010年調査にはその集計行「特別区」（13100）が並び、これは `district` です。

## 基本票と詳細票で母集団が違う

2012年調査から、全施設を数える基本票と、回収率の変動を受ける詳細票の2本立てになりました。2017年調査までは両方があり、2018年調査からは基本票だけです。`survey_form` を指定しないと1つの地域・施設に2行返ります。

```sql
-- 全国の定員の推移。基本票にそろえる
SELECT survey_year, facility_type, value AS capacity
FROM e_stat.kaigo_service.insurance_facility
WHERE area_kind = 'nationwide'
  AND measure = 'capacity'
  AND survey_form = '基本票'
ORDER BY survey_year, facility_type
```

基本票でそろえると、介護老人福祉施設の定員は2012年の475,695人から2024年の604,469人へ増え、介護老人保健施設は352,182人から365,939人とほぼ横ばいです。

票をまたぐと実体のない段差が出ます。介護老人福祉施設の施設数は2017年調査が詳細票7,299・基本票7,891で、詳細票から2018年調査の基本票8,097につなぐと1割の跳ねになります。

2011年調査までは票が1種類しか無いので `survey_form` は NULL です。原典は2010年・2011年調査と2012年〜2017年調査の詳細票に「調査方法の変更等による回収率変動の影響を受けているため、数量を示す施設数等の実数は前年以前と単純に年次比較できない」と注記しています。

## 施設の種類は年で入れ替わる

介護医療院は2018年調査から表に出ます（62施設 → 2024年調査で917施設）。入れ替わりに介護療養型医療施設が減り（2012年調査1,759施設 → 2023年調査197施設）、2024年調査では表から無くなります。

介護療養型医療施設の定員は原典の見出しが「病床数」ですが、数えているものは同じ枠の数なので `measure = 'capacity'` に寄せてあります。

## 地域コードは調査時点のもの

`area_code` は調査した年の標準地域コードです。平成の大合併で消えたコードも入っているので、2001年〜2024年調査に出る3,785コードのうち、現行の `code.municipality` に残るのは1,960です。

```sql
-- 現行の市区町村だけに絞る
SELECT f.area_name, f.value
FROM e_stat.kaigo_service.insurance_facility f
JOIN e_stat.code.municipality m ON m.area_code = f.area_code
WHERE f.survey_year = 2024
  AND f.facility_type = '介護老人保健施設'
  AND f.measure = 'capacity'
  AND m.is_municipality
ORDER BY f.value DESC
LIMIT 10
```

年をまたいで同じ市区町村を追うときは `code.municipality_change` で新旧のコードをつなぎます。収録は2007年4月2日以降の変更だけなので、平成の大合併のピーク（1999年〜2006年）はつながりません。

全国の行があるのは2004年調査からです。2001年〜2003年調査は都道府県から始まります。

## 常勤換算従事者数は2017年調査まで

`measure = 'fte_workers'` が入るのは2017年調査までで、2018年調査からは表にありません。原典が1の位で丸めた値なので、市区町村を足し上げても上位の行と一致しません（全国との最大差は市区町村の合計で118人、都道府県の合計で7人）。

## この調査に入っていない施設

保育所・障害者支援施設・児童養護施設・養護老人ホームなどは、この調査ではなく社会福祉施設等調査の対象です。[社会福祉施設の施設数・定員・従事者数](/cookbook/e_stat/welfare-facility)を参照してください。

訪問介護・通所介護などの居宅サービス事業所と地域密着型サービスの事業所数は、同じ調査の別の表にあります。この表には入っていません。

事業所1件ごとの名簿が必要なときは mhlw データセットの `kaigo.establishment` を参照してください。あちらは現時点の一覧で、年次の増減はこの表でしか追えません。

## 値が NULL の行

その年その市区町村にその種類の施設が無い行は NULL です。値が入るのは年・指標ごとに51.7%〜72.3%の行なので、集計の前に `value IS NOT NULL` で絞るか、`SUM` の NULL 無視に任せます。
