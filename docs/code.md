---
title: 標準地域コードと統計分類
order: 36
---

# 標準地域コードと統計分類

## 統計に用いる標準地域コード

都道府県・市区町村を 5 桁で表す「統計に用いる標準地域コード」の現行一覧と、
その変更（廃置分合）履歴です。area は census / boundary / SSDS の各テーブルが
用いる地域コードと同一体系で、コードから名称を引くマスタとして使えます。
全国地方公共団体コード（6 桁・チェックデジット付き）とは別体系です。

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| municipality | 現行の標準地域コード一覧 | area_code / pref_name / area_kind / is_municipality / municipality_code / municipality_name |
| municipality_change | コード変更（廃置分合）履歴 | effective_date / old_code / new_code / is_code_deleted / reason |

### 階層の判別

municipality は都道府県・政令指定都市・行政区・郡/振興局/支庁・市区町村を同一テーブルに
収録しています。どの階層の行かは `area_kind` で判別できます。

| area_kind | 件数 | 内容 |
|-----------|-----:|------|
| prefecture | 47 | 都道府県の合計行 |
| designated_city | 20 | 政令指定都市（行政区の親にあたる行） |
| ward | 171 | 政令指定都市の行政区 |
| district | 326 | 郡・振興局・支庁・特別区部（集計用の親行） |
| municipality | 1,727 | 市区町村 |

市区町村として数える行は `is_municipality` が真の行（1,747件）です。政令指定都市を
1団体として数え、行政区は数えません。

```sql
SELECT * FROM municipality WHERE is_municipality;
```

東京の特別区23は市区町村として数え、その親にあたる集計行「特別区部」（13100）は
数えません。同じ「区」でも行政区と特別区で扱いが逆になります。

`municipality_code` は所属する市区町村のコードです。行政区は所属市を、市区町村と
政令指定都市は自分自身を指します。行政区の粒度で来るデータを市区町村に寄せるときに、
どのコードでも同じキーで束ねられます。

```sql
-- 行政区のコードでも市区町村のコードでも、同じ市区町村に寄る
SELECT area_code, municipality_name, area_kind, municipality_code
FROM municipality
WHERE municipality_code = '22130';   -- 浜松市とその3行政区
```

`district_name` に同居していた郡名・振興局名・政令市名は `county_name` /
`subprefecture_name` / `designated_city_name` に分けています。北海道の町村は
振興局・支庁で括られていて郡名を持たないため、`county_name` は NULL になります。

municipality_change は旧コードから新コードへの対応を 1 件 1 行で収録します。編入・
合併で消滅したコードは new_name が「削除」表記になり is_code_deleted が真になります。
市区町村コード付きの時系列を合併をまたいで接続する横断キーとして使えます。
収録範囲は総務省が機械可読形式で提供する平成19年（2007年）4月2日以降の変更のみで、
平成の大合併のピーク（1999〜2006年）は含みません。

出典: 総務省統計局 統計に用いる標準地域コード。
https://www.soumu.go.jp/toukei_toukatsu/index/seido/9-5.htm

## 日本標準産業分類

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| industry | 日本標準産業分類の分類項目（4改定） | revision / level / code / name / parent_code / major_code |

令和5年7月改定（第14回）・平成25年10月改定・平成19年11月改定・平成14年3月改定の
4改定を、改定年 `revision`（2023 / 2013 / 2007 / 2002）と分類コード `code` の組で
1行ずつ収録します。大分類・中分類・小分類・細分類が同じ表に並び、`level` で分かります。

| revision | major | middle | minor | detail |
|---------:|------:|-------:|------:|-------:|
| 2023 | 20 | 99 | 536 | 1,473 |
| 2013 | 20 | 99 | 530 | 1,460 |
| 2007 | 20 | 99 | 529 | 1,455 |
| 2002 | 19 | 97 | 420 | 1,269 |

コードは大分類が英字1文字、中分類が数字2桁、小分類が3桁、細分類が4桁の文字列です。
`parent_code` が1つ上の階層、`major_code` が属する大分類を指すので、細分類のデータを
中分類や大分類にまとめるときはこの2列で寄せます。

```sql
-- 店舗データ（overturemaps の places.place）の産業中分類コードに名称と大分類を付ける
SELECT p.name, p.industry_code, m.name AS industry_name, j.name AS major_name
FROM overturemaps.places.place p
JOIN e_stat.code.industry m
    ON m.revision = 2023 AND m.level = 'middle' AND m.code = p.industry_code
JOIN e_stat.code.industry j
    ON j.revision = 2023 AND j.code = m.major_code
```

```sql
-- 工業統計の産業中分類コードに名称と大分類を付ける（工業統計は平成19年改定以降のコード）
SELECT f.survey_year, f.area, f.industry_code, m.name AS industry_name, j.name AS major_name, f.establishments
FROM e_stat.manufacture.municipality_industry f
JOIN e_stat.code.industry m
    ON m.revision = 2013 AND m.level = 'middle' AND m.code = f.industry_code
JOIN e_stat.code.industry j
    ON j.revision = 2013 AND j.code = m.major_code
WHERE f.industry_level = 2
```

同じコードでも改定によって中身が違います。令和5年改定では総合スーパー・
コンビニエンスストア・ドラッグストアなどの細分類（5621〜5661）ができ、平成25年改定に
あった細分類のいくつかは無くなりました。大分類の文字も平成14年改定（A〜S）と
それ以降（A〜T）で指す産業が違います。結合するときは必ず `revision` で改定を揃えます。
名称の区切りは平成25年改定までが全角カンマ「，」、令和5年改定が読点「、」なので、
名称で突き合わせると外れます。「管理，補助的経済活動を行う事業所」（各中分類の
xx0・xx00・xx09）は平成19年改定からの項目で、平成14年改定にはありません。

出典: 政府統計の総合窓口(e-Stat)（https://www.e-stat.go.jp/）統計分類・用語の検索
「日本標準産業分類」をもとに作成。
https://www.e-stat.go.jp/classifications/terms/10

## そのほかの統計分類

e-Stat の統計分類・用語の検索で公開されている、産業分類以外の統計分類です。どれも
改定（版）の年 `revision` と分類コード `code` の組で 1 行ずつ収録し、`parent_code` で
1 つ上の項目をたどれます。

| テーブル | 内容 | 改定（版） | 行数 |
|---------|------|-----------|-----:|
| occupation | 日本標準職業分類 | 2009 / 1997 | 415 / 458 |
| commodity | 日本標準商品分類 | 1990 | 37,041 |
| icd10 | 疾病、傷害及び死因の統計分類（基本分類） | 2013 / 2003 / 1994 | 15,339 / 14,553 / 14,531 |
| icd10_disease | 同 疾病分類（大分類表・中分類表・小分類表） | 2013 / 2003 / 1994 | 607 / 605 / 596 |
| icd10_cause_of_death | 同 死因分類 | 2013 / 2003 / 1994 | 133 / 133 / 130 |
| industry_economic_census | 経済センサス‐基礎調査の産業分類 | 2014 / 2009 | 705 / 707 |

- occupation は industry と同じ列（説明・事例・不適合事例）を持ちます。平成9年改定は
  大分類 I を I-1〜I-3 に分けていて、`level = 'major_group'` の行になります
- commodity の中分類（2桁）は先頭の数字が大分類と一致しません（大分類 1 の下に 01）。
  大分類へは `parent_code` でたどります。原典の再掲の行は収録していません
- icd10 のコードには原典の剣印（†）・星印（*）が付いたままです。記号の無いコードと
  結合するときは `rtrim(code, '†*')` で落とします
- icd10_disease の大分類表・中分類表・小分類表は細かさの違う別々の表で、
  `table_kind` で分かれます。icd10_disease と icd10_cause_of_death の `icd10_codes` は、
  その項目が含む基本分類のコードの範囲の原文です

```sql
-- ICD-10 の3桁分類に、属する章の名称を付ける
SELECT c.code, c.name, ch.name AS chapter_name
FROM e_stat.code.icd10 c
JOIN e_stat.code.icd10 ch
    ON ch.revision = c.revision AND ch.code = c.chapter_code
WHERE c.revision = 2013 AND c.level = 'category'
```

出典: 政府統計の総合窓口(e-Stat)（https://www.e-stat.go.jp/）統計分類・用語の検索
「日本標準職業分類」「日本標準商品分類」「疾病、傷害及び死因の統計分類」「経済センサス産業分類」をもとに作成。
https://www.e-stat.go.jp/classifications/terms

## 補足: code.industry

統計や店舗データが持つ産業分類コードから名称を引いたり、細分類を中分類・大分類にまとめたりするときに結合する。
令和5年改定で新しくできた細分類（5621〜5661の総合スーパー・コンビニエンスストア・ドラッグストアなど）もあれば、無くなった細分類もある。
名称の区切りも平成25年改定までは全角カンマ「，」、令和5年改定は読点「、」で、名称で突き合わせると外れる。

## 補足: code.municipality

都道府県・郡・市区町村を 5 桁の標準地域コード (area_code) で収録する。
国勢調査小地域・境界データ・社会人口統計体系 (SSDS) など本データセットの各テーブルが用いる地域コードと同体系で、コードから名称・よみがなを引くマスタとして使える。

## 補足: code.municipality_change

平成19年（2007年）4月2日以降に生じた市区町村の合併・編入・区の再編等を、旧コードから新コードへの対応として1件1行で収録する。
改正事由 (reason) が合併・編入の内容を、施行年月日 (effective_date) が発効日を示す。
市区町村コードを持つ既存の時系列（国勢調査小地域・SSDS 等）を合併をまたいで接続する横断キーとして使える。
