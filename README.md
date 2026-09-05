## データ出典

[e-Stat（政府統計の総合窓口）](https://www.e-stat.go.jp/)の API から取得した「社会・人口統計体系」のデータです。
都道府県別・市区町村別に、以下の11カテゴリの統計指標を収録しています。

## カテゴリ一覧

| カテゴリ | 都道府県テーブル | 市区町村テーブル |
|---------|---------------|---------------|
| A 人口・世帯 | pref_population | municipal_population |
| B 自然環境 | pref_land | municipal_land |
| C 経済基盤 | pref_economy | municipal_economy |
| D 行政基盤 | pref_administration | municipal_administration |
| E 教育 | pref_education | municipal_education |
| F 労働 | pref_labor | municipal_labor |
| G 文化・スポーツ | pref_culture | municipal_culture |
| H 居住 | pref_housing | municipal_housing |
| I 健康・医療 | pref_health | municipal_health |
| J 福祉・社会保障 | pref_welfare | municipal_welfare |
| K 安全 | pref_safety | municipal_safety |

## テーブル構造

全テーブル共通のカラム構成です。

- cat01: 分類事項の項目符号（例: 「J1102」）
- item_name: 分類事項名（例: 「J1102_現に保護を受けた生活保護被保護実世帯数」）
- cat01_parent: 上位項目の符号（5桁の項目は NULL）
- area / area_name: 地域コード / 地域名
- time_name: 時間軸名（例: 「2020年度」）
- year: time_name から抽出した西暦4桁
- unit: 単位（例: 「人」「km2」）
- value: 統計値

項目符号は[総務省の定義](https://www.stat.go.jp/data/ssds/2.html)で桁数が決まっています。
分野1文字 + 大分類1桁 + 小分類1桁 + 項目2桁 の5桁が項目で、その下に副区分が付いたものが
7桁以上です。副区分は1階層だけなので、5桁を超えるコードの親は先頭5桁になります。

```
A1101      総人口          （項目 = 5桁）
A110101    総人口（男）    （副区分。親は A1101）
```

項目と副区分が同じ列に混在するので、`cat01_parent` で切り分けます。

```sql
-- 項目だけ
SELECT * FROM e_stat.ssds.j_pref_welfare WHERE cat01_parent IS NULL;

-- 生活保護扶助世帯数（J1104）の副区分だけ
SELECT * FROM e_stat.ssds.j_pref_welfare WHERE cat01_parent = 'J1104';
```

副区分が親を分割しているとは限りません。A1101 のように男女で分割される系統もあれば、
J1102 のように「うち」項目だけが並んでいて親に届かない系統もあります。
親自身がデータを持たないこともあります（分類項目名だけが定義され、副区分のみ
公開されている系統が 621 件）。

地域も同様に、都道府県版は全国計（area = 00000）を、市区町村版は政令指定都市の
合計行と行政区をどちらも含みます。市区町村単位で数えるときは
`code.municipality` の `is_municipality` で絞ります。

## 指標別の収録年（ssds.series_coverage）

収録年は指標ごとに違います。毎年更新される系列と、国勢調査ベースで5年ごとの系列が
同じテーブルに混在するため、テーブル全体の `MAX(year)` は「どこまで新しいか」の
答えになりません。`a_pref_population` はテーブルとしては 2025 年まで入っていますが、
2025 年に届く指標は 594 のうち 12 だけで、307 は 2020 年で止まります。

`ssds.series_coverage` が指標ごとの収録年を持っています。22テーブル分をまとめた
約 5,000 行の表で、22テーブルを走査せずに引けます。

```sql
SELECT table_name, cat01, item_name, min_year, max_year, year_count
FROM e_stat.ssds.series_coverage
WHERE table_name = 'c_municipal_economy'
  AND cat01 IN ('C120110', 'C120120')
```

`year_count` が `max_year - min_year + 1` に満たなければ、その系列は年が飛んでいます。

収録年は地域をまたいだ和です。`max_year` は「どこかの地域で」その年まで入っていることを
表すので、地域を1つに絞って使うときは、その地域にその年の行があるかを別に確かめます
（`c_municipal_economy` では199指標中114指標で最新年が地域ごとに違います）。

## 国勢調査 小地域集計（census スキーマ）

令和2年国勢調査の町丁・字等別（小地域）集計です。area は同データセットの境界データ
small_area の key_code と同一体系で、`key_code = area` で境界ポリゴンと結合できます。
area には市区町村・町丁・字等・その内訳の3階層が含まれ、粒度は `area_level` で判別
できます。桁数を揃えずに合計すると重複します。
分類は cat01（主分類）、cat02（秘匿・合算区分: 無し/合算/秘匿）です。

| テーブル | 内容 | cat01 | value |
|---------|------|-------|-------|
| census_small_area_age | 年齢（5歳階級・4区分）別、男女別人口 | 男女・年齢区分 | 人口 |
| census_small_area_household | 世帯の家族類型別一般世帯数 | 家族類型 | 一般世帯数 |
| census_small_area_industry | 産業（大分類）別就業者数 | 産業大分類 | 就業者数 |
| census_small_area_housing | 住宅の所有の関係別一般世帯数 | 住宅の種類・所有の関係 | 一般世帯数 |

### 地域の粒度

| area_level | 桁数 | 内容 | 総人口の合計 |
|-----------|-----:|------|------------:|
| municipality | 5 | 市区町村 | 126,146,099 |
| small_area | 9 | 町丁・字等 | 126,146,099 |
| small_area_detail | 11 | 丁目など町丁・字等の内訳 | 80,726,789 |

`municipality` と `small_area` はどちらも全域を覆い、合計は一致します。
`small_area_detail` は丁目に分かれている地域にしかないため全域を覆いません。

```sql
-- 町丁・字等の粒度だけ（全域を覆い、重複しない）
SELECT * FROM e_stat.census.census_small_area_age WHERE area_level = 'small_area';
```

境界データと結合するときは `area_level` で絞らないでください。`boundary.small_area`
は末端の区画だけを1行ずつ持つ（丁目に分かれている地域は 11桁の行しか無い）ため、
`small_area` に絞ってから結合すると全国で 4,530万人分（36%）しか残りません。
`area = key_code` でそのまま結合すれば、末端の区画が自然に選ばれて 1億2603万人に
なります。

4表とも cat02 は秘匿・合算区分です。census_small_area_age だけ名称列が sex という
名前ですが、中身は他の3表の secrecy と同じ秘匿・合算区分で、男女は cat01 側
（総数 / 男 / 女 × 年齢区分）に入っています。主分類の名称列はテーブルごとに
age_class / family_type / industry / tenure として展開しています。

秘匿（cat02 = 3）の行は value が 0 で入りますが「0」ではなく非公表で、実数は
合算（cat02 = 2）の地域に含まれています。そのまま合計すると実態より小さくなります。

出典: 総務省統計局 令和2年国勢調査 小地域集計（統計GIS）。https://www.e-stat.go.jp/gis

## 国勢調査 市区町村別 基本集計（census スキーマ）

令和2年国勢調査 人口等基本集計の第1-1-1表・第1-1-2表・第1-1-3表を、地域1行の
横持ちにまとめた census_municipality です。人口・男女別人口・世帯数・世帯人員・
5年前との人口／世帯の増減・人口性比・面積・人口密度を持ちます。

area は全国・都道府県・市区町村・政令指定都市の区・2000年（平成12年）市区町村が
同じ列に縦に並びます。粒度は area_level で判別します。

| area_level | 内容 | 地域数 | 人口の合計 |
|-----------|------|-------:|----------:|
| national | 全国 | 1 | 126,146,099 |
| prefecture | 都道府県 | 47 | 126,146,099 |
| city | 市・特別区部 | 793 | 115,757,942 |
| town_village | 町村 | 926 | 10,388,157 |
| ward | 政令指定都市の区・特別区 | 198 | 37,532,334 |
| former_municipality | 2000年（平成12年）市区町村 | 2,121 | 53,303,248 |

日本全域をちょうど1回覆うのは `prefecture` だけ、または `city` と `town_village` の
組だけです。`ward` は `city` の内訳（千代田区は特別区部の内訳、札幌市中央区は札幌市の
内訳）、`former_municipality` は現行市区町村を2000年の区域で組み替えた再掲なので、
足すと二重に数えます。

```sql
-- 市区町村単位の人口ランキング（全域を覆い、重複しない）
SELECT area_name, population, population_density
FROM e_stat.census.census_municipality
WHERE area_level IN ('city', 'town_village')
ORDER BY population DESC
LIMIT 10;
```

面積（area_km2）は北方領土と竹島を含みますが、人口密度（population_density）の
分母はそれらを除いた面積です。`population / area_km2` は原典の人口密度と一致しません
（全国で約4,984km2、根室市で約95km2の差）。

東日本大震災で全町避難が続いた富岡町・大熊町・双葉町・浪江町の4町は、2015年の人口・
世帯数と増減率が原典で「-」のため NULL です。増減数のほうは原典が2015年を0として
出しているので、増減として読めません。双葉町は2020年の人口も非公表で NULL ですが、
人口密度だけ 0.0 が入ります。

出典: 総務省統計局 令和2年国勢調査 人口等基本集計。https://www.e-stat.go.jp/

## 国勢調査 市区町村別 就業状態等基本集計（census スキーマ）

令和2年国勢調査 就業状態等基本集計から、市区町村・都道府県の粒度で労働力状態と
従業上の地位を取った2表です。どちらも縦持ちで、年齢は総数のみです。

| テーブル | 内容 | 区分の列 | 値 |
|---------|------|---------|----|
| census_municipality_labor_force | 男女・労働力状態別 15歳以上人口 | labor_status_code / labor_status | 人口 |
| census_municipality_employment_status | 男女・従業上の地位別 就業者数 | employment_status_code / employment_status | 就業者数 |

area は census_municipality と同じ標準地域コード（5桁）で、2000年（平成12年）市区町村の
再掲を除いた1,965地域です。粒度は area_level で判別します。

| area_level | 内容 | 地域数 | 15歳以上人口の合計 |
|-----------|------|-------:|------------------:|
| national | 全国 | 1 | 108,258,569 |
| prefecture | 都道府県 | 47 | 108,258,569 |
| city | 市・特別区部 | 793 | 99,161,646 |
| town_village | 町村 | 926 | 9,096,923 |
| ward | 政令指定都市の区・特別区 | 198 | 31,968,922 |

区分は総数・大区分・その内訳が同じ列に縦に並びます。深さは labor_status_level /
employment_status_level に出ていて、絞らずに合計すると何重にも数えます。男女
（sex_code）も総数・男・女が同じ列に並ぶので、併せて絞ります。

```sql
-- 市区町村別の労働力率（労働力人口 ÷ 15歳以上人口）
SELECT
    area_name,
    MAX(value) FILTER (WHERE labor_status_code = '1')
        / MAX(value) FILTER (WHERE labor_status_code = '0') AS labor_force_rate
FROM e_stat.census.census_municipality_labor_force
WHERE sex_code = '0' AND area_level IN ('city', 'town_village')
GROUP BY area, area_name
ORDER BY labor_force_rate DESC
LIMIT 10;
```

従業上の地位には「（再掲）雇用者（役員を含む）」があり、level は大区分と同じ 1 です。
合計するときは is_reprint = false も併せて絞ります。

```sql
-- 市区町村別の非正規雇用の割合（派遣社員 + パート・アルバイト ÷ 雇用者）
SELECT
    area,
    area_name,
    SUM(value) FILTER (WHERE employment_status_code IN ('12', '13'))
        / SUM(value) FILTER (WHERE employment_status_code = '1') AS nonregular_share
FROM e_stat.census.census_municipality_employment_status
WHERE sex_code = '0' AND area_level IN ('city', 'town_village')
GROUP BY area, area_name
ORDER BY nonregular_share DESC
LIMIT 10;
```

census_municipality_employment_status の総数は、census_municipality_labor_force の
就業者（labor_status_code = '11'）と全行で一致します。

原典が「-」の区分は NULL です。内訳の合計が総数と一致することから、「-」は該当者が
いない（0人）ことを表します。全町避難が続いた双葉町だけは全行が「-」で、全項目が
NULL になります。

出典: 総務省統計局 令和2年国勢調査 就業状態等基本集計（第1-2-1表・第3-2表）。
https://www.e-stat.go.jp/

## 国勢調査 昼夜間人口と通勤・通学流動（census スキーマ）

令和2年国勢調査 従業地・通学地による人口・就業状態等集計から、市区町村・都道府県の粒度で
昼夜間人口と通勤・通学の流動を取った2表です。どちらも縦持ちで、年齢は総数のみです。

| テーブル | 内容 | 区分の列 | 値 |
|---------|------|---------|----|
| census_municipality_daytime_population | 男女・常住地／従業地・通学地別 人口 | location_code / location | 人口 |
| census_commuting_flow | 常住地 → 従業地・通学地（都道府県）別 通勤者・通学者数 | destination_area / destination_area_name | 通勤者・通学者数 |

area は census_municipality と同じ標準地域コード（5桁）で、2000年（平成12年）市区町村の
再掲を除いた1,965地域です。census_commuting_flow では area が常住地を指します。

| area_level | 内容 | 地域数 | 夜間人口の合計 |
|-----------|------|-------:|--------------:|
| national | 全国 | 1 | 126,146,099 |
| prefecture | 都道府県 | 47 | 126,146,099 |
| city | 市・特別区部 | 793 | 115,757,942 |
| town_village | 町村 | 926 | 10,388,157 |
| ward | 政令指定都市の区・特別区 | 198 | 37,532,334 |

### 昼夜間人口

census_municipality_daytime_population は夜間人口（常住地による人口）側と昼間人口
（従業地・通学地による人口）側が同じ列に縦に並びます。どちら側かは population_base、
階層の深さは location_level に出ています。

```sql
SELECT area_name, value AS daytime_population
FROM e_stat.census.census_municipality_daytime_population
WHERE sex_code = '0' AND location_code = '1' AND area_level = 'ward'
ORDER BY value DESC
LIMIT 10;
```

昼夜間人口比率は昼間人口 ÷ 夜間人口 × 100 です。原典の第1-1-2表の公表値と一致します
（千代田区は 903,780 ÷ 66,680 × 100 = 1355.39892）。

```sql
SELECT
    area,
    area_name,
    MAX(value) FILTER (WHERE location_code = '0') AS nighttime_population,
    MAX(value) FILTER (WHERE location_code = '1') AS daytime_population,
    ROUND(
        MAX(value) FILTER (WHERE location_code = '1') * 100.0
        / MAX(value) FILTER (WHERE location_code = '0'), 1
    ) AS daytime_ratio
FROM e_stat.census.census_municipality_daytime_population
WHERE sex_code = '0' AND area_level IN ('city', 'town_village')
GROUP BY area, area_name
ORDER BY daytime_ratio DESC
LIMIT 10;
```

昼間人口 = 夜間人口 − 流出人口 + 流入人口 が全1,965地域・男女3区分で成り立ちます。
流出人口・流入人口（is_reprint = true の2区分）が指す範囲は area_level で変わります。
市区町村（区・町村・政令指定都市以外の市）は自市内他区・県内他市町村・他県の3区分の和、
政令指定都市と特別区部は県内他市町村・他県の2区分の和、都道府県は他県のみ、全国は NULL です。

### 通勤・通学流動

census_commuting_flow は1行が「常住地 → 従業地・通学地」1組にあたる OD（起終点）行列です。
従業地・通学地は都道府県までで、市区町村どうしの流動は含みません。

```sql
SELECT area, area_name, value AS commuters_to_tokyo
FROM e_stat.census.census_commuting_flow
WHERE destination_area = '13000'
  AND sex_code = '0'
  AND area_level IN ('city', 'town_village')
  AND area NOT LIKE '13%'
ORDER BY value DESC NULLS LAST
LIMIT 10;
```

常住地と同じ都道府県のセルには自市区町村内で従業・通学する人（自宅外）も入ります。
「県外へ出る人」を数えるには、destination_area が常住地の都道府県コードと違う行だけを取ります。

数えているのは自宅外で従業・通学する人だけで、自宅で従業する人と従業も通学もしていない人は
含みません。census_municipality_daytime_population の「自宅外の自市区町村で従業・通学」
（0022）と「他市区町村で従業・通学」（003）の和に、この表の従業地・通学地「不詳」（99999）を
足したものが destination_area_level = 'total' の値に一致します。

原典が「-」の区分は NULL です。census_municipality_daytime_population は112,005行のうち
11,360行、census_commuting_flow は294,750行のうち175,672行が NULL で、いずれも該当者が
いない（0人）ことを表します。

出典: 総務省統計局 令和2年国勢調査 従業地・通学地による人口・就業状態等集計（第1-1-1表・第6-1表）。
https://www.e-stat.go.jp/

## 1kmメッシュ別 昼間人口（census スキーマ）

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| daytime_population_mesh_1km | 1kmメッシュ別 昼間人口・夜間人口・昼夜間人口比率 | mesh_code / city_code / nighttime_population / daytime_population / daytime_ratio |

夜間人口は令和2年国勢調査の実測値ですが、昼間人口は推計値です。公的統計として
昼間人口が公表されているのは市区町村までで、それより細かい単位は存在しません。

市区町村の公表値の内訳（A6101〜A6106）を「その場に残る人（A6101 + 不詳）」と
「そこで従業・通学する人（A6102 + A6105 + A6106）」に分け、前者をメッシュの夜間人口、
後者をメッシュの従業者数をウェイトに配分しています。ウェイトは市区町村の中で
正規化するので、メッシュを市区町村ごとに合計すると公表昼間人口（A6107）に一致します。

従業者数のウェイトは平成28年経済センサス（A～R全産業、S公務を除く）です。
官公庁の集積と通学による流入は反映されません。買い物客・観光客は含みません
（公表昼間人口も同じ定義です）。

使い方と注意点は[1kmメッシュ別 昼間人口のガイド](docs/mesh-daytime.md)を参照してください。

出典: 総務省統計局 令和2年国勢調査／平成28年経済センサス‐活動調査に関する地域メッシュ統計、
社会・人口統計体系。https://www.e-stat.go.jp/

## 経済センサス 産業大分類別の事業所数・従業者数・売上金額（economic_census スキーマ）

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| establishment_industry | 全国・都道府県・市区町村別、産業大分類別・経営組織別の民営事業所数・従業者数・売上（収入）金額 | area / industry_code / organization_code / establishments / employees / sales_million_yen |

令和3年経済センサス‐活動調査（2021年6月1日現在）の産業横断的集計「売上（収入）金額等」
第2-1表です。国勢調査の census_small_area_industry が常住地ベース（住民がどの産業で働くか）
なのに対し、こちらは従業地ベース（事業所がどの産業か）です。

事業所数の母数がほかの表と違います。全国・全産業の事業所数は 4,870,898 で、事業所に関する
集計の民営事業所数 5,156,063 とは一致しません。売上（収入）金額等の集計は必要な事項の数値が
得られた事業所だけを対象にするためで、ほかの統計表の事業所数と突き合わせる用途には
使えません。

### 総数と内訳

総数と内訳が同じ列に縦に並ぶ軸が3つあります。絞らずに合計すると何重にも数えます。

産業（industry_code）の深さは industry_level に出ています。重複なく全産業を覆うのは
AB（農林漁業）と industry_level = 2 の16区分を合わせた17区分で、その和が AR（全産業）に
一致します。

経営組織（organization_code）は 0（総数）= 1（個人）+ 2（会社）+ 3（会社以外の法人）です。
S1・S2 は内数の別掲なので is_reprint で落とします。

地域（area）は area_level で判別します。

| area_level | 内容 | 地域数 | 事業所数の合計 |
|-----------|------|-------:|--------------:|
| national | 全国 | 1 | 4,870,898 |
| prefecture | 都道府県 | 47 | 4,870,898 |
| municipality | 市・町村・特別区部 | 1,719 | 4,870,898 |
| ward | 政令指定都市の行政区・特別区・境界未定地域 | 199 | 1,537,160 |

特別区は ward に入り、その親「特別区部」（13100）が municipality に立ちます。特別区部には
23区のほかに境界未定地域（13199）も含まれます。

```sql
-- 全国の産業別 事業所数・従業者数（重複なく数える17区分）
SELECT industry_code, industry_name, establishments, employees
FROM e_stat.economic_census.establishment_industry
WHERE area = '00000' AND organization_code = '0'
  AND (industry_code = 'AB' OR industry_level = 2)
ORDER BY establishments DESC;
```

### 売上（収入）金額が無い産業

売上（収入）金額は産業によって調査されておらず、建設業・電気ガス熱供給水道業・
情報通信業・運輸業郵便業・金融業保険業・教育学習支援業・複合サービス事業・
サービス業（他に分類されないもの）は NULL です。内訳の一部が欠けるため、全産業（AR）と
非農林漁業（CR）の売上も NULL になります。事業所数と従業者数は全産業で揃っています。

原典が区分ごとに丸めているため、売上（収入）金額は内訳の和が総数と最大1百万円ずれる
産業があります。

1事業所当たり売上（収入）金額と従業者1人当たり売上（収入）金額は、この表の事業所数・
従業者数で割り直した値とは一致しません（原典の分母が違い、両方が揃う約6.1万行のうち
一致するのは1.4万行未満です）。1事業所当たり従業者数は従業者数÷事業所数に一致します。

```sql
-- 市区町村別 卸売業，小売業の従業者1人当たり売上（万円）
SELECT area_name, employees, sales_per_employee_10k_yen
FROM e_stat.economic_census.establishment_industry
WHERE industry_code = 'I' AND organization_code = '0'
  AND area_level = 'municipality' AND employees >= 10000
ORDER BY sales_per_employee_10k_yen DESC
LIMIT 10;
```

原典が「-」（該当数字なし）・「･･･」（調査していないもの）・「X」（秘匿）の区分は NULL に
なり、3つの意味は区別できません。

出典: 総務省・経済産業省 令和3年経済センサス‐活動調査 事業所に関する集計
産業横断的集計 売上（収入）金額等（第2-1表）。https://www.e-stat.go.jp/

## 家計調査 品目別の支出金額・購入数量（household スキーマ）

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| expenditure | 二人以上の世帯の品目別支出金額。全国と県庁所在市等53地域の月次・年次 | cat01 / item_name / item_level / item_parent / cat02 / area / frequency / year / month / unit / value |
| quantity | 二人以上の世帯の品目別購入数量。月次は全国のみ、年次は53地域 | 同上 |

家計調査 家計収支編 二人以上の世帯の品目分類（2025年改定）です。2025年改定の統計表は
1985年1月まで遡って組み替えられているので、旧改定（平成17／22／27年・2020年）の表は
取り込んでいません。

統計表全体では月次が1985年1月〜2026年6月、年次が1985年〜2025年ですが、収録期間は
世帯区分と地域で違います（後述）。

cpi.price_index と突き合わせると、値上がりと支出・数量の動きを並べられます。ただし
地域コードの体系が違います。札幌市は household が `01003`、cpi が `01A01` で、`area` で
結合すると全国（`00000`）しか当たりません。市の名称（`area_name`）はどちらも
「01100 札幌市」の形で一致するので、そちらで結合します。

### 月次と年次

月次と年次を1つの表に積んであります。時間軸コードが衝突しない（月次は 2024000101、
年次は 2024000000）ので、`frequency` で絞ります。絞らずに合計すると二重に数えます。

年次は年平均ではなく12か月の合計（年間額・年間量）です。ただし単位が円でない項目
（世帯人員・世帯主の年齢・持家率など）だけは年平均で、合計にはなりません。

### 品目の階層

総額・費目・品目が同じ列に縦に並びます。深さは item_level、親は item_parent に出ています。

item_level = 1 は22項目あって、消費支出・10大費目に加えて財・サービス支出計や
消費支出(基礎・選択)といった別集計、さらに世帯人員のような世帯属性まで同居しています。
level = 1 を足し上げても消費支出にはなりません。消費支出（001100000）と一致するのは
10大費目（010000000〜100000000）の合計です。

```sql
-- 食料の内訳（2024年・全国・二人以上の世帯）
SELECT item_name, value
FROM e_stat.household.expenditure
WHERE item_parent = '010000000'
  AND cat02 = '03' AND area = '00000' AND frequency = '年次' AND year = 2024
ORDER BY value DESC;
```

### 世帯区分

cat02 に4区分あります。01・02 は農林漁家世帯を除くベース、03・04 はそれを含むベースです。
区分名の括弧内は「（1985年～2007年,2017年）」となっていますが、実データは 01・02 が
1985〜2017年の連続、03・04 が2000年〜で、**2000〜2017年の18年は両方に行があります**。
絞らずに集計するとその18年を二重に数えます。

地域別の内訳を持つのは 03（二人以上の世帯）だけです。04（うち勤労者世帯）には
全国の行しかありません。

### 地域

全国と、47県庁所在市に川崎市・相模原市・浜松市・堺市・北九州市を加えた52市の53区分です。
都道府県別はありません。東京は「13100 東京都区部」で、特別区をまとめた1行です。
area_name の先頭に付く5桁が標準地域コードで、area 自体（01003 など）とは別体系です。

市の行が始まる時期は全国より遅く、月次は2007年9月からです。1985〜1999年の月次は
cat02 = 01・02（農林漁家世帯を除く）の全国行にしかありません。

### 数量と単価

quantity は数量を調査している204品目だけです。単位は品目ごとに違う（米は1kg、パンは1g、
電気代は1kWh）ので、品目をまたいで足せません。月次は全国だけで、県庁所在市別は年次のみです。

品目コードは expenditure と共通なので、両表を結合すると単価が出ます。

```sql
-- 全国の米の1kg当たり支出額（2024年・月次）
SELECT e.time_name, e.value AS yen, q.value AS kg, e.value / q.value AS yen_per_kg
FROM e_stat.household.expenditure e
JOIN e_stat.household.quantity q
  ON e.cat01 = q.cat01 AND e.cat02 = q.cat02 AND e.area = q.area AND e.time = q.time
WHERE e.cat01 = '010110001' AND e.cat02 = '03' AND e.area = '00000'
  AND e.frequency = '月次' AND e.year = 2024
ORDER BY e.month;
```

出典: 総務省統計局 家計調査 家計収支編 二人以上の世帯 品目分類（2025年改定）。
https://www.stat.go.jp/data/kakei/

## 労働力調査 就業状態別人口・完全失業率（labor スキーマ）

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| labor_force | 就業状態別15歳以上人口（万人）。全国の月次と地域ブロック別の四半期 | frequency / industry_code / sex_code / labor_status_code / labor_status / labor_status_level / age_class_code / area / year / month / quarter / unit / value |
| labor_force_rate | 労働力人口比率・就業率・完全失業率（％）。粒度は labor_force と同じ | frequency / sex_code / indicator_code / indicator / age_class_code / area / year / month / quarter / unit / value |

労働力調査 基本集計です。全国は月次で1968年1月から、地域ブロック別は四半期で
2000年1〜3月期から収録しています。都道府県別はありません。標本設計が地域ブロックまでなので、
都道府県別の就業者数・完全失業率が要るときは就業構造基本調査か県別の推計を使います。

社会・人口統計体系の `ssds.pref_labor` / `ssds.municipal_labor`（F 労働）とは別物です。
あちらは各種統計から集めた労働分野の指標で、労働力調査の原表ではありません。

### 単位は万人

`value` の単位は人ではなく万人です。`unit` にも「万人」と入っています。
値は万人単位で丸められているので、内訳を足しても総数と数万人ずれます。

### 全国の月次と地域ブロックの四半期

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

### 就業状態の階層

15歳以上人口・労働力人口・就業者・完全失業者・非労働力人口が同じ列に縦に並びます。
深さは `labor_status_level` に出ていますが、level = 1 は入れ子の総数を含みます
（15歳以上人口 ⊃ 労働力人口 ⊃ 就業者 ⊃ 従業者）。足し上げても総数にはなりません。

成り立つのは次の2つです。

- 労働力人口（`01`）= 就業者（`02`）+ 完全失業者（`08`）
- 就業者（`02`）= 従業者（`03`）+ 休業者（`07`）

15歳以上人口（`00`）は労働力人口と非労働力人口（`09`）の合計より数万人多くなります
（実測で最大13万人）。差はこの表に区分の無い就業状態不詳の分で、この恒等式は成り立ちません。

### 年齢階級

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

### 産業の内訳がある状態

`industry_code` は全産業（`000`）・農業，林業（`001`）・非農林業（`004`）の3区分です。
内訳を持つのは就業者・従業者・休業者など就業者系の状態だけで、15歳以上人口・労働力人口・
完全失業者・非労働力人口には全産業の行しかありません。産業を絞らずに集計すると、
就業者だけが3重になります。地域ブロックの四半期は産業を分けない集計なので、
一律 `000` が入っています。

産業中分類までの内訳は同じ調査の別表にあり、この2テーブルには入っていません。

### 完全失業率の分母

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

## 統計に用いる標準地域コード（code スキーマ）

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

## 境界データ（boundary スキーマ）

地図化・空間集計に使う区画のポリゴンです。統計値は持ちません。

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| small_area | 令和2年国勢調査 町丁・字等別境界 | key_code / prefecture_code / city_code / area_name / geometry |
| mesh_1km | 標準地域メッシュ 3次メッシュ（1kmメッシュ）境界 | mesh_code / mesh1_code / mesh2_code / mesh3_code / geometry |

mesh_1km は標準地域メッシュ（JIS X 0410）の区画そのものです。mesh_code は 8 桁の
3次メッシュコードで、上位から 1次メッシュ（約80km四方・4桁）、2次メッシュ
（約10km四方・2桁）、3次メッシュ（約1km四方・2桁）に分解できます。各桁は
mesh1_code / mesh2_code / mesh3_code にも分けて持たせています。同じコード体系を使う
メッシュ統計と `mesh_code` で結合して地図に載せられます。1 区画の大きさは緯度方向
30 秒・経度方向 45 秒で、南鳥島・沖ノ鳥島を含む陸域の 1次メッシュ 176 区画分
（501,600 メッシュ）を収録しています。座標系は EPSG:4612 です。

出典: 総務省統計局 統計GIS 境界データ。https://www.e-stat.go.jp/gis

## 住民基本台帳 人口・世帯数・人口動態（resident_registry スキーマ）

全国・都道府県・市区町村ごとの人口・世帯数と、その1年間の出生・死亡・転入・転出です。
国勢調査が5年に1度なのに対しこちらは毎年で、1968年から2026年まで途切れなく続きます。

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| population | 住民基本台帳に基づく人口・世帯数・人口動態（年次） | reference_date / resident_kind / area_level / area_code / population_total / households / births / deaths / moved_in_total / moved_out_total |

### 調査期日と動態の対象期間

`reference_date` は2014年以降が1月1日、2013年以前が3月31日です。人口動態はその期日の
直前1年間で、1月1日基準の年は前年1月1日から12月31日、3月31日基準の年は前年度4月1日から
当年3月31日にあたります。基準日の切り替えをまたぐ2013年と2014年の間だけ、動態の対象
期間が3か月重なります。

1979年以前は人口と世帯数だけで、出生・死亡・転入・転出は NULL です。転入・転出の
国内／国外の内訳が付くのは2013年以降です。

### 住民区分

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

### 地域の粒度

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

## ライセンス

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
