---
$schema: https://queria.io/schemas/table/v1.json
table: resident_registry.population
title: 住民基本台帳 人口・世帯数・人口動態（市区町村別・年次）
description: |-
  住民基本台帳に基づく人口・世帯数と1年間の出生・死亡・転入・転出を、全国・都道府県・市区町村ごとに1968年から年次で持つテーブルです。

  - 調査期日は2014年以降が1月1日、2013年以前が3月31日です
  - 住民区分（総計・日本人・外国人）と地域の粒度が同じ列に並ぶので、絞ってから合計してください
keywords:
  - e-stat
  - 住民基本台帳
  - 住基人口
  - 人口
  - 世帯数
  - 人口動態
  - 転入
  - 転出
  - 出生
  - 死亡
  - 市区町村
  - 都道府県
  - 外国人住民
sources:
  - path: https://www.soumu.go.jp/main_sosiki/jichi_gyousei/daityo/jinkou_jinkoudoutai-setaisuu.html
fields:
  - name: reference_date
    title: 調査期日（2014年以降は1月1日、2013年以前は3月31日）
    description: 人口・世帯数の調査期日。2014年以降は1月1日、2013年以前は3月31日。人口動態はこの日の直前1年間の値
  - name: year
    title: 年（reference_date の年）
    description: reference_date の年。年次の時系列を並べるときの軸
  - name: resident_kind
    title: 住民区分（total / japanese / foreign）
    description: 住民区分。total=総計、japanese=日本人住民、foreign=外国人住民。3区分が同じ列に縦に積まれるので、絞らずに合計すると二重に数える。3区分に分かれるのは2013年以降で、2012年以前は住民基本台帳が日本人住民のみを対象としていたため japanese だけになる
  - name: area_level
    title: 地域の粒度（national / prefecture / municipality）
    description: 地域の粒度。national=全国計、prefecture=都道府県、municipality=市区町村。集計行と明細行が同じ表に同居するので、絞らずに合計すると重複する。municipality には郡・政令指定都市の合計・行政区も含まれる
  - name: area_code
    title: 標準地域コード（5桁）
    description: 標準地域コード（5桁）。lg_code の先頭5桁で、census / boundary / soumu.code.municipality と同じ体系。政令市とその区、郡とその町村を数え分けるには、このコードで soumu.code.municipality を引いて area_kind / is_municipality を見る。全国計の行と、コードを持たない行では NULL
    semantic: {role: entity, name: city}
  - name: lg_code
    title: 全国地方公共団体コード（6桁）
    description: 全国地方公共団体コード（6桁・チェックデジット付き）。元データの団体コードそのまま。全国計の行は NULL。東京都の島しょ集計行と2009年の北方領土6村もコードを持たず NULL になる
    semantic: {role: entity, name: city}
  - name: pref_name
    title: 都道府県名
    description: 都道府県名。全国計の行では NULL
  - name: municipality_name
    title: 市区町村名
    description: 市区町村名。元データの表記そのままで、郡に属する町村は「宮古郡多良間村」、政令市の区は「札幌市中央区」のように上位の名称が前に付く。全国計・都道府県の行では NULL
  - name: population_total
    title: 人口（人）
    description: 人口（人）。2025年以降の外国人住民には在留カードの性別欄が空欄の住民が含まれ、その分だけ男女の合計より大きくなる（2026年で全国74人）
  - name: population_male
    title: 男の人口（人）
    description: 男の人口（人）
  - name: population_female
    title: 女の人口（人）
    description: 女の人口（人）
  - name: households
    title: 世帯数（世帯）
    description: 世帯数（世帯）。日本人住民の区分では日本人住民のみの世帯と複数国籍の世帯の合計
  - name: births
    title: 出生者数（人）
    description: 出生者数（人）。1980年より前の年は収録が無く NULL
  - name: deaths
    title: 死亡者数（人）
    description: 死亡者数（人）。1980年より前の年は収録が無く NULL
  - name: natural_change
    title: 自然増減数（人）
    description: 自然増減数（人）。出生者数 - 死亡者数
  - name: moved_in_total
    title: 転入者数 計（人）
    description: 転入者数の計（人）。1980年より前の年は収録が無く NULL
  - name: moved_in_domestic
    title: 転入者数 国内（人・2013年以降）
    description: 国内からの転入者数（人）。国内・国外の内訳が付くのは2013年以降で、それ以前は NULL
  - name: moved_in_overseas
    title: 転入者数 国外（人・2013年以降）
    description: 国外からの転入者数（人）。国内・国外の内訳が付くのは2013年以降で、それ以前は NULL
  - name: moved_out_total
    title: 転出者数 計（人）
    description: 転出者数の計（人）。1980年より前の年は収録が無く NULL
  - name: moved_out_domestic
    title: 転出者数 国内（人・2013年以降）
    description: 国内への転出者数（人）。国内・国外の内訳が付くのは2013年以降で、それ以前は NULL
  - name: moved_out_overseas
    title: 転出者数 国外（人・2013年以降）
    description: 国外への転出者数（人）。国内・国外の内訳が付くのは2013年以降で、それ以前は NULL
  - name: social_change
    title: 社会増減数（人）
    description: 社会増減数（人）。増減数 - 自然増減数にあたり、転入転出だけでなく職権記載・職権消除・帰化・国籍喪失といったその他の増減も含む。転入者数 - 転出者数とは一致しない
  - name: other_added
    title: 住民票記載数 その他（人）
    description: 住民票記載数のうち、転入・出生以外の計（人）。職権記載、帰化、国籍喪失などを含む
  - name: other_removed
    title: 住民票消除数 その他（人）
    description: 住民票消除数のうち、転出・死亡以外の計（人）。職権消除、帰化、国籍喪失などを含む
  - name: total_added
    title: 住民票記載数 計（人）
    description: 住民票記載数の計（人）。転入者数 + 出生者数 + その他
  - name: total_removed
    title: 住民票消除数 計（人）
    description: 住民票消除数の計（人）。転出者数 + 死亡者数 + その他
  - name: net_change
    title: 増減数（人）
    description: 増減数（人）。住民票記載数の計 - 住民票消除数の計
themes: [population]
---

# 住民基本台帳 人口・世帯数・人口動態

全国・都道府県・市区町村ごとの人口・世帯数と、その1年間の出生・死亡・転入・転出です。
国勢調査が5年に1度なのに対しこちらは毎年で、1968年から2026年まで途切れなく続きます。

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| population | 住民基本台帳に基づく人口・世帯数・人口動態（年次） | reference_date / resident_kind / area_level / area_code / population_total / households / births / deaths / moved_in_total / moved_out_total |

## 調査期日と動態の対象期間

`reference_date` は2014年以降が1月1日、2013年以前が3月31日です。人口動態はその期日の
直前1年間で、1月1日基準の年は前年1月1日から12月31日、3月31日基準の年は前年度4月1日から
当年3月31日にあたります。基準日の切り替えをまたぐ2013年と2014年の間だけ、動態の対象
期間が3か月重なります。

1979年以前は人口と世帯数だけで、出生・死亡・転入・転出は NULL です。転入・転出の
国内／国外の内訳が付くのは2013年以降です。

## 住民区分

`resident_kind` は総計（total）・日本人住民（japanese）・外国人住民（foreign）が同じ列に
縦に積まれています。絞らずに合計すると二重に数えます。

3区分に分かれるのは2013年以降です。2012年以前は住民基本台帳が日本人住民のみを対象と
していたため japanese だけになります（外国人住民は2012年7月の法改正で対象になりました）。
日本人住民の系列だけが1968年から連続します。

```sql
-- 全国人口の年次推移（日本人住民、1968年から連続）
SELECT year, population_total
FROM population
WHERE area_level = 'national' AND resident_kind = 'japanese'
ORDER BY year;
```

## 地域の粒度

`area_level` は national（全国計）・prefecture（都道府県）・municipality（市区町村）です。
municipality の行には郡・政令指定都市の合計・その行政区も含まれるので、絞らずに合計すると
政令市とその区、郡とその町村を二重に数えます。日本全域をちょうど1回覆う集計には
`area_code` で soumu.code.municipality を引き、`is_municipality` で絞ります。

```sql
-- 2026年1月1日時点で人口の多い市区町村（政令市は1団体、行政区は数えない）
SELECT p.pref_name, p.municipality_name, p.population_total
FROM population p
JOIN municipality m ON m.area_code = p.area_code
WHERE p.year = 2026 AND p.resident_kind = 'total'
  AND p.area_level = 'municipality' AND m.is_municipality
ORDER BY p.population_total DESC
LIMIT 10;
```

`area_code` は `lg_code`（全国地方公共団体コード・6桁）の先頭5桁で、census / boundary /
soumu.code.municipality と同じ標準地域コードです。東京都の島しょ集計行と2009年の北方領土6村は
元データが団体コードを持たないため、`lg_code` と `area_code` が NULL になります。

合併で消滅したコードは現行の soumu.code.municipality に無いため、古い年ほど結合できない行が
増えます（2026年は2,226行すべてが結合でき、1995年は3,881行のうち1,857行）。この結合で
絞った合計が全国計とちょうど一致するのは2019年以降で、それより前は消滅したコードの分だけ
少なくなります。合併をまたいで接続するには code.municipality_change を使いますが、機械可読な
履歴は2007年4月2日以降のみです。

`social_change`（社会増減数）は増減数から自然増減数を引いた値で、転入転出だけでなく
職権記載・職権消除・帰化・国籍喪失といったその他の増減も含みます。
`moved_in_total - moved_out_total` とは一致しません。

出典: 総務省 住民基本台帳に基づく人口、人口動態及び世帯数。
https://www.soumu.go.jp/main_sosiki/jichi_gyousei/daityo/jinkou_jinkoudoutai-setaisuu.html

## 補足: resident_registry.population

総計 = 日本人住民 + 外国人住民 は全行で成り立つ。
