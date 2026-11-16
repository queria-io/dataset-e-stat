---
$schema: https://queria.io/schemas/table/v1.json
table: welfare_facility.facility_statistics
title: 社会福祉施設等の施設数・定員・在所者数・従事者数（都道府県別）
description: |-
  社会福祉施設等調査の施設数・定員・在所者数・従事者数を、都道府県別・施設の種類別・経営主体別に2011年から持つテーブルです。

  - 介護保険の施設は含みません（kaigo_service にあります）
  - facility_level = 'type' の段だけが足し合わせて全体になります
  - 2023年から幼保連携型認定こども園が対象外になり、保育所等の定員が下がります
keywords:
  - e-stat
  - 社会福祉施設等調査
  - 社会福祉施設
  - 保育所
  - 認定こども園
  - 老人福祉施設
  - 障害者支援施設
  - 児童養護施設
  - 介護
  - 福祉
  - 定員
  - 在所者数
  - 従事者数
  - 都道府県
sources:
  - path: https://www.e-stat.go.jp/stat-search/files?toukei=00450041
fields:
  - name: survey_year
    title: 調査年
    description: "調査年。毎年10月1日現在の調査で、2011〜2024で欠けは無い"
  - name: area_kind
    title: 地域の種別
    description: "地域の種別。nationwide=全国、state=国（国が設置する施設）、prefecture=都道府県、designated_city=指定都市、core_city=中核市。指定都市と中核市の行があるのは2011年〜2017年調査だけ"
  - name: area_code
    title: 地域コード
    description: "統計に用いる標準地域コード（5桁）。soumu.code.municipality の area_code と直接つながる。全国と国の行は NULL"
    semantic: {role: entity, name: city}
  - name: area_name
    title: 地域名
    description: "地域の名称。都道府県は原典の表記に接尾辞を補ってある（原典は2022年調査まで「青森」、2023年調査から「青森県」）"
  - name: prefecture_code
    title: 都道府県コード
    description: "都道府県コード（2桁）。指定都市・中核市の行にはその市が属する都道府県が入る。2017年調査までの都道府県の行は市の分を含まないので、都道府県の通年の系列はこの列で束ねて足し合わせる。全国と国の行は NULL"
    semantic: {role: entity, name: prefecture}
  - name: facility_code
    title: 施設の種類の符号
    description: "施設の種類の符号（4桁）。原典が施設の種類の名称に前置している番号。大分類の小計・内訳・再掲には付かない。2024年調査の女性自立支援施設のように、足し合わせる段にいながら符号を持たない種類もあるので、段の判定には facility_level を使う"
  - name: facility_type
    title: 施設の種類
    description: "施設の種類の名称。符号は facility_code に切り出してあるので名称だけが入る。名称は年で変わる（婦人保護施設は2024年調査から女性自立支援施設、情緒障害児短期治療施設は2017年調査から児童心理治療施設）"
  - name: facility_parent
    title: 上位の施設の種類
    description: "原典の見出しで facility_type の 1 つ上に立つ施設の種類。保育所は保育所等の内訳、小規模保育事業所Ａ型は地域型保育事業所の内訳。一番上の段にいる種類は NULL。2014年調査までの定員・在所者数の表は見出しが1段しかなく上の段を印字しないので、符号から同じ年の別の表の大分類を当てて補ってある"
  - name: facility_group
    title: 施設の大分類
    description: "施設の大分類。保護施設・老人福祉施設・障害者支援施設等・児童福祉施設等など。大分類そのものの行と、大分類に属さない種類（婦人保護施設・女性自立支援施設）は NULL。2014年調査までの定員・在所者数の表は大分類を印字しないので、符号から同じ年の別の表の大分類を当てて補ってある"
  - name: facility_level
    title: 集計の段
    description: "原典の集計表での段。type=足し合わせると全体になる段、group=大分類の小計、detail=保育所等・地域型保育事業所を割った内訳、reprint=再掲、total=全体の総数。type 以外を混ぜて足すと二重に数える"
  - name: operator
    title: 経営主体
    description: "経営主体。総数・公営・私営の3値で、公営 + 私営 = 総数"
  - name: survey_form
    title: 調査票
    description: "調査票。基本票は全施設、詳細票は一部が標本。定員は両方の票にあり母集団が違う。2011年調査は票が1種類しか無いので NULL"
  - name: measure
    title: 指標
    description: "指標。facility_count=施設数（施設・事業所）、capacity=定員（人）、occupants=在所者数（人）、fte_workers=常勤換算従事者数（人）。母子生活支援施設の定員は世帯数、在所者数は世帯人員数、有料老人ホーム（サービス付き高齢者向け住宅であるもの）の定員は戸数、助産施設の定員は認可病床数で、単位が人ではない"
  - name: value
    title: 値
    description: "指標の値。その年その地域にその種類の施設が無いか、原典が値を伏せた行は NULL。負の値は無い。総数には原典が外している施設がある（定員・在所者数の総数は母子生活支援施設を含まず、2011年調査の定員はさらに助産施設を含まない）"
themes: [social_security_health]
---

# 社会福祉施設等調査（facility_statistics）

保育所・障害者支援施設・児童養護施設・養護老人ホームなどの施設数・定員・在所者数・常勤換算従事者数を、都道府県別・施設の種類別・経営主体別に収録します。テーブルは `e_stat.welfare_facility.facility_statistics`。2011年から2024年までの864,063行で、調査日は毎年10月1日です。

出典: [厚生労働省 社会福祉施設等調査](https://www.e-stat.go.jp/stat-search/files?toukei=00450041)

## 列の使い方

1セル1行の縦持ちです。指標を `measure` で選び、地域と施設の種類で絞ります。

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

特別養護老人ホーム（介護老人福祉施設）・介護老人保健施設・訪問介護事業所などの介護保険の施設は、この調査ではなく介護サービス施設・事業所調査の対象です。介護保険施設の施設数と定員は[介護保険施設の施設数・定員](../../../docs/kaigo_service/index.md)にあります。

事業所1件ごとの名簿が必要なときは mhlw データセットの `kaigo.establishment` と `shougai.shougai_establishment` を参照してください。あちらは現時点の一覧で、年次の増減はこの表でしか追えません。

## 値が NULL の行

その年その地域にその種類の施設が無いか、原典が値を伏せた行は NULL です。値が入るのは年・指標ごとに34.4%〜63.3%の行なので、集計の前に `value IS NOT NULL` で絞るか、`SUM` の NULL 無視に任せます。

## 補足: 社会福祉施設等調査 施設数・定員・在所者数・従事者数（welfare_facility スキーマ）

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| facility_statistics | 都道府県別・施設の種類別の施設数・定員・在所者数・従事者数 | survey_year / area_kind / area_code / area_name / prefecture_code / facility_code / facility_type / facility_level / operator / survey_form / measure / value |

1セル1行の縦持ちで、指標は `measure` で選びます（`facility_count` 施設数、`capacity` 定員、
`occupants` 在所者数、`fte_workers` 常勤換算従事者数）。値が入るのは年・指標ごとに
34.4%〜63.3%の行で、残りはその年その地域にその種類の施設が無いか、原典が値を伏せた行です。

## 補足: welfare_facility.facility_statistics

特別養護老人ホームなど介護保険の施設は介護サービス施設・事業所調査の対象で、この統計には入らない。
同じ領域の事業所名簿が現時点の一覧しか持たないのに対して、こちらは年次の増減を追える。
収録は2011年〜2024年調査の14年、864,063行。
指標（measure）は施設数 facility_count・定員 capacity・在所者数 occupants・常勤換算従事者数 fte_workers の4つ。
常勤換算従事者数は原典が四捨五入した整数で、小数は入らない。
地域は全国・国・47都道府県が全年にそろい、2011年〜2017年調査にはこれに加えてその年の指定都市（19〜20市）と中核市（41〜48市）の行がある。
2017年調査までの都道府県の行は市の分を含まないので、都道府県で通しの系列を作るときは prefecture_code で足し合わせる。
大分類の小計・保育所等の内訳・再掲を混ぜると二重に数える。
2023年調査から幼保連携型認定こども園が調査の対象外になり、保育所等の定員が2,939,776人（2022年）から 2,259,096人（2023年）に落ちる。
減少ではなく対象の変更。
https://www.e-stat.go.jp/stat-search/files?toukei=00450041厚生労働省ポータル: https://www.mhlw.go.jp/toukei/list/23-22.html
