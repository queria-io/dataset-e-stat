# e-Stat 統計データ

政府統計の総合窓口（e-Stat）の API と統計GIS から取得した日本の公的統計を、SQL で検索・集計できるテーブルにしたデータセットです。社会・人口統計体系（SSDS）を中心に、国勢調査、経済センサス、人口動態調査など約 30 の統計をスキーマごとに収録しています。

## 出典と利用条件

- [e-Stat（政府統計の総合窓口）](https://www.e-stat.go.jp/)と[統計GIS](https://www.e-stat.go.jp/gis)
- 各統計の作成府省（総務省統計局・経済産業省・厚生労働省・国税庁・農林水産省・国土交通省など）

[政府標準利用規約（第2.0版）](https://www.e-stat.go.jp/terms-of-use)に従います。

このサービスは、政府統計総合窓口(e-Stat)のAPI機能を使用していますが、サービスの内容は国によって保証されたものではありません。

## スキーマ

スキーマごとのテーブルの構成・列・注意は、右の列のページにまとめています。

| スキーマ | 内容 | 説明 |
| --- | --- | --- |
| `ssds` | 社会・人口統計体系。都道府県・市区町村別の11分野の指標 | [説明](docs/ssds/index.md) |
| `cpi` | 消費者物価指数 | [説明](models/cpi/mart/price_index.md) |
| `corporate_finance` | 法人企業統計調査 | [説明](docs/corporate_finance/index.md) |
| `main` | 統計表カタログ・指標定義 | [説明](docs/catalog.md) |
| `census` | 国勢調査（小地域・市区町村・昼夜間人口・通勤通学・メッシュ） | [説明](docs/census/index.md) |
| `boundary` | 町丁・字等と1kmメッシュの境界 | [説明](docs/boundary/index.md) |
| `code` | 標準地域コードと統計分類（産業・職業・商品・ICD-10 など） | [説明](docs/code/index.md) |
| `resident_registry` | 住民基本台帳の人口・世帯数・人口動態 | [説明](models/resident_registry/mart/population.md) |
| `economic_census` | 経済センサス‐活動調査 | [説明](docs/economic_census/index.md) |
| `economic_structure` | 経済構造実態調査 | [説明](docs/economic_structure/index.md) |
| `enterprise_activity` | 経済産業省企業活動基本調査 | [説明](docs/enterprise_activity/index.md) |
| `household` | 家計調査 | [説明](docs/household/index.md) |
| `labor` | 労働力調査 | [説明](docs/labor/index.md) |
| `production` | 経済産業省生産動態統計 | [説明](models/production/mart/monthly.md) |
| `manufacture` | 工業統計調査 | [説明](models/manufacture/mart/municipality_industry.md) |
| `migration` | 住民基本台帳人口移動報告 | [説明](docs/migration/index.md) |
| `local_finance` | 地方財政状況調査 | [説明](docs/local_finance/index.md) |
| `retail_price` | 小売物価統計調査 | [説明](models/retail_price/mart/item_price.md) |
| `welfare_facility` | 社会福祉施設等調査 | [説明](models/welfare_facility/mart/facility_statistics.md) |
| `kaigo_service` | 介護サービス施設・事業所調査 | [説明](docs/kaigo_service/index.md) |
| `kaigo_insurance` | 介護保険事業状況報告 | [説明](docs/kaigo_insurance/index.md) |
| `medical_facility` | 医療施設調査 | [説明](models/medical_facility/mart/municipality_facility.md) |
| `employment_structure` | 就業構造基本調査 | [説明](models/employment_structure/mart/employment_status.md) |
| `wage_structure` | 賃金構造基本統計調査 | [説明](docs/wage_structure/index.md) |
| `private_salary` | 民間給与実態統計調査 | [説明](models/private_salary/mart/industry_salary_class.md) |
| `school` | 学校基本調査 | [説明](docs/school/index.md) |
| `school_health` | 学校保健統計調査 | [説明](models/school_health/mart/growth_by_prefecture.md) |
| `business_outlook` | 法人企業景気予測調査 | [説明](docs/business_outlook/index.md) |
| `building_starts` | 建築着工統計調査 | [説明](models/building_starts/mart/municipality_use.md) |
| `commerce` | 商業動態統計調査 | [説明](models/commerce/mart/sales_by_business_monthly.md) |
| `job_placement` | 一般職業紹介状況（職業安定業務統計） | [説明](docs/job_placement/index.md) |
| `construction` | 建設総合統計・建設工事受注動態統計調査 | [説明](docs/construction/index.md) |
| `rail_transport` | 鉄道輸送統計調査 | [説明](models/rail_transport/mart/passengers_monthly.md) |
| `port` | 港湾調査 | [説明](models/port/mart/cargo_tonnage_annual.md) |
| `housing_survey` | 住宅・土地統計調査 | [説明](models/housing_survey/mart/municipality_income_tenure.md) |
| `trade` | 普通貿易統計（品別国別表） | [説明](models/trade/mart/commodity_country_monthly.md) |
| `crop` | 作物統計調査（野菜） | [説明](models/crop/mart/vegetable_production.md) |
| `household_structure` | 全国家計構造調査 | [説明](models/household_structure/mart/income_class_expenditure.md) |
| `vital_statistics` | 人口動態調査 | [説明](docs/vital_statistics/index.md) |
| `energy_consumption` | エネルギー消費統計調査 | [説明](docs/energy_consumption/index.md) |

## 使い方

都道府県の総人口（SSDS の A1101）を最新年で並べる:

```sql
SELECT area_name, year, value AS population
FROM e_stat.ssds.a_pref_population
WHERE cat01 = 'A1101' AND area <> '00000'
QUALIFY year = max(year) OVER ()
ORDER BY value DESC;
```

## 注意

- 多くのテーブルは全国・都道府県・市区町村・政令指定都市の区などの行を同じ列に持ちます。絞らずに合計すると何重にも数えるので、地域の階層で絞ってから集計してください。
- `soumu.code.municipality` などの 5 桁の地域コードは、全国地方公共団体コード（6 桁、チェックディジット付き）とは別の体系です。`lg_code` や `address_br` と結合するときは桁と体系を統一してください。
- 国勢調査の小地域の `area` は `boundary.small_area` の `key_code` と同じ体系です。小地域の統計を地図に載せるときはこの列で結合します。

## 更新

```bash
uv sync
bash scripts/build.sh
```

## 新しい統計表の公開に気付く（watch_stats.yml）

Check updates のワークフローは毎週月曜に、`watch_stats.yml` に載せた統計について、過去 7 日に
新しく公開された統計表を e-Stat の統計表情報（getStatsList）で探します。見つかったら統計ごとに
issue を立てます。国勢調査の町丁・字別のような小地域の表は `search_kinds: [1, 2]` で探します。
取り込むと決めたら、表を `tables.yml` か `local_tables.yml` に足します。

見張る統計を足すときは `watch_stats.yml` に政府統計コードを足します。毎月・毎週の表が出る統計
（家計調査・人口推計など）は issue が多くなるので入れません。手で回すときは Actions の画面から
Check updates を実行し、`days` で探す日数を、`dry_run` で issue を立てずに結果だけ出すかを選びます。

## 更新された表だけを取り直す統計表（小地域・1km メッシュ）

国勢調査の小地域統計と 1km メッシュ統計（`main.py` の 8・9）は、都道府県や 1 次メッシュごとに
600 表あまりあり、全部を取ると 110 分かかります。毎日の Sync は、getStatsList が返す表ごとの
更新日を `_source.loaded_stats_tables` に記録した値と比べ、更新日が変わった表とまだ取り込んで
いない表だけを取得します（`pipelines/loaded_tables.py`）。記録はロードが成功したあとに書くので、
途中で落ちた表は次の Sync で取り直されます。更新日は日付単位で、同じ日に 2 回直された表を見落とすことがあるので、
毎月 1 日（UTC）の Sync は記録を見ずに全表を取り直します。全部を取り直したいときは、その表の行を
`loaded_stats_tables` から消します。

作物統計（`main.py` の 21、1,425 表）も同じ考え方で、getStatsData の応答を表ごとに更新日と一緒に
`_source.crop_responses` に置き、更新日が変わった表と新しい表だけを取得します。整形は毎回すべての
表の応答から作り直します。毎月 1 日は置いた応答を使わずに全表を取り直します。

## 手元で1回だけ取り込む統計表（local_tables.yml）

数年に1度しか出ない統計は、毎日の更新（CI）で e-Stat から取り直しません。Sync の時間を
食うためです。`local_tables.yml` に載せた表は手元で1回だけ取得・公開し、CI は公開済みの
元表を読んでビルドするだけです。

```bash
# 1. e-Stat から取得して data/local/<グループ>/ に保存する
uv run --env-file .env python load_local.py fetch census_2025
# 2. CI の Sync が走っていないときに、ロードして対象のモデルだけビルドし、公開する
uv lock --upgrade-package fdl-cli && uv sync
FDL_TOKEN=... scripts/build.sh --env-file .env python load_local.py load census_2025
```

`local_tables.yml` の `updated_date` は取り込んだときの e-Stat の更新日です。毎週
Check updates のワークフローが e-Stat の更新日と比べ、変わっていたら issue を立てます。
表に `watch: false` を付けると見張りから外れます。毎期更新される統計表の過去の期だけを取る表
（`api_params` の `cdTimeTo` で期を絞った corporate_finance_history）に使います。この表の境目は
tables.yml の `initial_time` と接しているので、動かすときは両方を一緒に直します。
取り込み直すときは `updated_date` を直してから 1 と 2 を回します（fetch は食い違うと止まります）。

表を足すときは `local_tables.yml` にグループ（`tables` と、ロード後にビルドする `dbt_select`）を
書き、`models/*/raw/_sources.yml` に元表を足します。分類の並び順にしか入っていない情報
（医療施設調査の二次医療圏と市区町村の所属など）を読むグループは `class_order: true` を付けます。
fetch が分類軸ごとの並び順を `<軸>_order` 列（cat01_order など）として残します。

普通貿易統計の品別国別表（trade グループ）は、過去の年だけを手元で取り込み、新しい年は CI の
Sync が毎日取り直します。境目は `catalog_filter.through_year` です。Check updates も through_year
までの年のファイルだけを見張ります。境目を進めるときは、through_year と catalog_modified_date・
各表の updated_date を直し、`fetch trade` と `load trade` を回してから PR にします。先に境目だけを
進めると、その年が手元の分にも CI の分にも入らなくなります。

統計表データベース（API）に無く、ファイル（Excel）でだけ配られる統計は、グループに `fetcher` と
`stats_code` を書きます。fetch は `pipelines/<fetcher>.py` の `fetch_local` に取得を任せ、
Check updates は表の更新日の代わりに、その政府統計コードのファイルの最終更新日（`catalog_modified_date`）を比べます。

市区町村コードと名前の履歴（municipality_history グループ、`code.municipality_name`）は、e-Stat の
「市区町村を探す」の画面からダウンロードします。1970年4月1日と廃置分合等の施行日ごとに市区町村コードの一覧を
取るので、取得に 30 分ほどかかります。`catalog_modified_date` には廃置分合等の一覧の最新の施行日を書き、
Check updates はこれと比べます。
