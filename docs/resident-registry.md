---
title: 住民基本台帳 人口・世帯数・人口動態
order: 38
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
`area_code` で code.municipality を引き、`is_municipality` で絞ります。

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
code.municipality と同じ標準地域コードです。東京都の島しょ集計行と2009年の北方領土6村は
元データが団体コードを持たないため、`lg_code` と `area_code` が NULL になります。

合併で消滅したコードは現行の code.municipality に無いため、古い年ほど結合できない行が
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
