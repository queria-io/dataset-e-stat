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
| `ssds` | 社会・人口統計体系。都道府県・市区町村別の11分野の指標 | [説明](ssds/index.md) |
| `cpi` | 消費者物価指数 | [説明](cpi/price_index.md) |
| `corporate_finance` | 法人企業統計調査 | [説明](corporate_finance/index.md) |
| `main` | 統計表カタログ・指標定義 | [説明](catalog.md) |
| `census` | 国勢調査（小地域・市区町村・昼夜間人口・通勤通学・メッシュ） | [説明](census/index.md) |
| `boundary` | 町丁・字等と1kmメッシュの境界 | [説明](boundary/index.md) |
| `code` | 標準地域コードと統計分類（産業・職業・商品・ICD-10 など） | [説明](code/index.md) |
| `resident_registry` | 住民基本台帳の人口・世帯数・人口動態 | [説明](resident_registry/population.md) |
| `economic_census` | 経済センサス‐活動調査 | [説明](economic_census/index.md) |
| `economic_structure` | 経済構造実態調査 | [説明](economic_structure/index.md) |
| `enterprise_activity` | 経済産業省企業活動基本調査 | [説明](enterprise_activity/index.md) |
| `household` | 家計調査 | [説明](household/index.md) |
| `labor` | 労働力調査 | [説明](labor/index.md) |
| `production` | 経済産業省生産動態統計 | [説明](production/monthly.md) |
| `manufacture` | 工業統計調査 | [説明](manufacture/municipality_industry.md) |
| `migration` | 住民基本台帳人口移動報告 | [説明](migration/index.md) |
| `local_finance` | 地方財政状況調査 | [説明](local_finance/index.md) |
| `retail_price` | 小売物価統計調査 | [説明](retail_price/item_price.md) |
| `welfare_facility` | 社会福祉施設等調査 | [説明](welfare_facility/facility_statistics.md) |
| `kaigo_service` | 介護サービス施設・事業所調査 | [説明](kaigo_service/index.md) |
| `kaigo_insurance` | 介護保険事業状況報告 | [説明](kaigo_insurance/index.md) |
| `medical_facility` | 医療施設調査 | [説明](medical_facility/municipality_facility.md) |
| `employment_structure` | 就業構造基本調査 | [説明](employment_structure/employment_status.md) |
| `wage_structure` | 賃金構造基本統計調査 | [説明](wage_structure/index.md) |
| `private_salary` | 民間給与実態統計調査 | [説明](private_salary/industry_salary_class.md) |
| `school` | 学校基本調査 | [説明](school/index.md) |
| `school_health` | 学校保健統計調査 | [説明](school_health/growth_by_prefecture.md) |
| `business_outlook` | 法人企業景気予測調査 | [説明](business_outlook/index.md) |
| `building_starts` | 建築着工統計調査 | [説明](building_starts/municipality_use.md) |
| `commerce` | 商業動態統計調査 | [説明](commerce/sales_by_business_monthly.md) |
| `job_placement` | 一般職業紹介状況（職業安定業務統計） | [説明](job_placement/index.md) |
| `construction` | 建設総合統計・建設工事受注動態統計調査 | [説明](construction/index.md) |
| `rail_transport` | 鉄道輸送統計調査 | [説明](rail_transport/passengers_monthly.md) |
| `port` | 港湾調査 | [説明](port/cargo_tonnage_annual.md) |
| `housing_survey` | 住宅・土地統計調査 | [説明](housing_survey/municipality_income_tenure.md) |
| `trade` | 普通貿易統計（品別国別表） | [説明](trade/commodity_country_monthly.md) |
| `crop` | 作物統計調査（野菜） | [説明](crop/vegetable_production.md) |
| `household_structure` | 全国家計構造調査 | [説明](household_structure/income_class_expenditure.md) |
| `vital_statistics` | 人口動態調査 | [説明](vital_statistics/index.md) |
| `energy_consumption` | エネルギー消費統計調査 | [説明](energy_consumption/index.md) |

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
