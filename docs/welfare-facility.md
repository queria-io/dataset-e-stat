---
title: 社会福祉施設の施設数・定員・従事者数
order: 24
---

# 社会福祉施設等調査（facility_statistics）

保育所・障害者支援施設・児童養護施設・養護老人ホームなどの施設数・定員・在所者数・常勤換算従事者数を、都道府県別・施設の種類別・経営主体別に収録します。テーブルは `e_stat.welfare_facility.facility_statistics`。2011年から2024年までの864,063行で、調査日は毎年10月1日です。

出典: [厚生労働省 社会福祉施設等調査](https://www.e-stat.go.jp/stat-search/files?toukei=00450041)

## カラム構成

1セル1行の縦持ちです。指標を `measure` で選び、地域と施設の種類で絞ります。

- survey_year: 調査年
- area_kind / area_code / area_name: 地域の種別 / 標準地域コード / 地域名
- prefecture_code: 都道府県コード。市の行にはその市が属する都道府県が入る
- facility_code / facility_type: 施設の種類の符号 / 名称
- facility_parent / facility_group: 1つ上の段 / 大分類
- facility_level: 集計表での段（`type` / `group` / `detail` / `reprint` / `total`）
- operator: 経営主体（`総数` / `公営` / `私営`）
- survey_form: 調査票（`基本票` / `詳細票`）
- measure: 指標（`facility_count` / `capacity` / `occupants` / `fte_workers`）
- value: 値

## 施設の種類を探す

```sql
SELECT DISTINCT facility_code, facility_type, facility_group
FROM e_stat.welfare_facility.facility_statistics
WHERE survey_year = 2024 AND facility_level = 'type'
ORDER BY facility_code
```

## 全国の推移を見る

```sql
SELECT survey_year, value
FROM e_stat.welfare_facility.facility_statistics
WHERE facility_code = '0910'      -- 障害者支援施設
  AND measure = 'facility_count'
  AND area_kind = 'nationwide'
  AND operator = '総数'
ORDER BY survey_year
```

## 都道府県で並べる

```sql
SELECT area_name, value
FROM e_stat.welfare_facility.facility_statistics
WHERE survey_year = 2024
  AND facility_code = '0400'      -- 保育所等
  AND measure = 'capacity' AND survey_form = '基本票'
  AND area_kind = 'prefecture'
  AND operator = '総数'
ORDER BY value DESC
```

2024年の保育所等の定員は東京都が321,215人で最も多く、愛知県162,053人、神奈川県156,176人と続きます。

## 都道府県の時系列は市の行を足してから作る

2017年調査までは指定都市と中核市が都道府県とは別の行に並び、**都道府県の行はその市の分を含みません**。2018年調査からは市の行が無くなり、都道府県の行が県全体になります。`area_kind = 'prefecture'` だけで年をまたぐと、2018年に実体のない跳ねが出ます。

```sql
-- 有料老人ホームの施設数。全国と国を除いて prefecture_code で束ねる
SELECT survey_year, SUM(value) AS facilities
FROM e_stat.welfare_facility.facility_statistics
WHERE facility_code = '0900'
  AND measure = 'facility_count'
  AND operator = '総数'
  AND prefecture_code IS NOT NULL
GROUP BY survey_year
ORDER BY survey_year
```

束ねると 2017年 13,525 → 2018年 14,454 と続きますが、`area_kind = 'prefecture'` だけで数えると 7,821 → 14,454 になります。差は指定都市と中核市の分です。

国が設置する施設は `area_kind = 'state'` の行にあり、どの都道府県にも属しません（`prefecture_code` が NULL）。上のクエリはこれを外しています。

## 足し合わせる段は facility_level = 'type'

施設の種類の見出しは段になっていて、そのまま足すと二重に数えます。足し合わせて全体になるのは `facility_level = 'type'` の段だけです。

- `type`: 足し合わせて全体になる段
- `group`: 保護施設・老人福祉施設・児童福祉施設等などの大分類の小計
- `detail`: 保育所等を幼保連携型認定こども園・保育所・保育所型認定こども園に割った内訳、地域型保育事業所を小規模保育事業所などに割った内訳
- `reprint`: 再掲
- `total`: 全体の総数

```sql
-- 2024年の大分類ごとの施設数
SELECT facility_group, SUM(value) AS facilities
FROM e_stat.welfare_facility.facility_statistics
WHERE survey_year = 2024
  AND measure = 'facility_count'
  AND area_kind = 'nationwide'
  AND operator = '総数'
  AND facility_level = 'type'
GROUP BY facility_group
ORDER BY facilities DESC
```

`facility_level = 'type'` の行で `facility_group` が NULL になるのは、大分類に属さない婦人保護施設（2024年調査からは女性自立支援施設）だけです。大分類そのものの行（`group`）・総数の行（`total`）・再掲の一部は `facility_group` を持たないので、`facility_level` で絞らずに `GROUP BY facility_group` すると NULL の束にそれらが混ざります。2014年調査までの定員・在所者数の表は原典が大分類を印字しませんが、施設の種類の符号から同じ年の別の表の大分類を当てて補ってあるので、年をまたいでまとめても落ちません。

## 基本票と詳細票で母集団が違う

2012年調査から、全施設に配る基本票と一部が標本の詳細票の2本立てになりました。定員は両方にあるので、`survey_form` を指定しないと1つの地域・施設に2行返ります。

- 施設数: 基本票
- 定員: 基本票と詳細票の両方
- 在所者数・常勤換算従事者数: 詳細票

2024年の全国の総数は、基本票の定員が3,770,139人、詳細票の定員が3,506,823人、在所者数が2,971,644人、常勤換算従事者数が1,018,802人です。定員に対する在所者数を見るときは、分母も詳細票の定員にそろえます。

```sql
-- 保育所等の定員と在所者数（2024年・都道府県別）
SELECT
    area_name,
    SUM(value) FILTER (WHERE measure = 'occupants') AS occupants,
    SUM(value) FILTER (WHERE measure = 'capacity') AS capacity
FROM e_stat.welfare_facility.facility_statistics
WHERE survey_year = 2024
  AND facility_code = '0400'
  AND survey_form = '詳細票'
  AND area_kind = 'prefecture'
  AND operator = '総数'
GROUP BY area_name
ORDER BY occupants / capacity DESC
```

2011年調査は票が1種類しか無いので `survey_form` は NULL です。

## 在所者数が定員を超える施設の種類がある

在所者数は定員と同じものを数えていません。通所で利用する人を含む施設の種類では、在所者数が定員を上回ります（2024年の全国で、児童発達支援センターは定員25,043人に対し在所者数47,619人、障害者支援施設は定員135,475人に対し在所者数145,488人）。母子生活支援施設は定員が世帯数、在所者数が世帯人員数で、そもそも単位が違います。都道府県 × 施設の種類で見ると、在所者数が定員を超える組合せは19.4%あります。定員に対する割合として読めるのは、入所・入園の定員で運営する種類（保育所等は2024年の全国で84.6%）だけです。

## 2023年に幼保連携型認定こども園が対象から外れた

2023年調査から幼保連携型認定こども園が調査の対象外になりました。保育所等の定員は2022年の2,939,776人から2023年は2,259,096人に、施設数の総数は83,821から77,803に下がります。減ったのではなく数える範囲が変わったので、2022年をまたぐ比較はこの施設を外してそろえます。

## 総数に入っていない施設がある

定員と在所者数の総数には母子生活支援施設が入りません。2011年調査の定員はさらに助産施設も外れます。原典の集計がそうなっているので、`facility_level = 'type'` を足した値は総数より母子生活支援施設の分だけ大きくなります。

単位が人でない施設もあります。母子生活支援施設の定員は世帯数、在所者数は世帯人員数、有料老人ホーム（サービス付き高齢者向け住宅であるもの）の定員は戸数、助産施設の定員は認可病床数です。

## 施設の種類の名称は年で変わる

符号が同じでも名称が変わります。婦人保護施設は2024年調査から女性自立支援施設、情緒障害児短期治療施設は2017年調査から児童心理治療施設です。2011年調査は障害者総合支援法より前の区分で、知的障害者援護施設・身体障害者更生援護施設・精神障害者社会復帰施設という大分類があり、2012年調査以降の障害者支援施設等とは範囲が違います。

## この調査に入っていない施設

特別養護老人ホーム（介護老人福祉施設）・介護老人保健施設・訪問介護事業所などの介護保険の施設は、この調査ではなく介護サービス施設・事業所調査の対象です。

事業所1件ごとの名簿が必要なときは mhlw データセットの `kaigo.establishment` と `shougai.shougai_establishment` を参照してください。あちらは現時点の一覧で、年次の増減はこの表でしか追えません。

## 値が NULL の行

その年その地域にその種類の施設が無いか、原典が値を伏せた行は NULL です。値が入るのは年・指標ごとに34.4%〜63.3%の行なので、集計の前に `value IS NOT NULL` で絞るか、`SUM` の NULL 無視に任せます。
