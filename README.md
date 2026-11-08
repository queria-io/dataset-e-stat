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
| `ssds` | 社会・人口統計体系。都道府県・市区町村別の11分野の指標 | [index.md](docs/index.md) |
| `cpi` | 消費者物価指数 | [cpi.md](docs/cpi.md) |
| `corporate_finance` | 法人企業統計調査 | [corporate-finance.md](docs/corporate-finance.md) |
| `main` | 統計表カタログ・指標定義 | [catalog.md](docs/catalog.md) |
| `census` | 国勢調査（小地域・市区町村・昼夜間人口・通勤通学・メッシュ） | [census.md](docs/census.md) |
| `boundary` | 町丁・字等と1kmメッシュの境界 | [boundary.md](docs/boundary.md) |
| `code` | 標準地域コードと日本標準産業分類 | [code.md](docs/code.md) |
| `resident_registry` | 住民基本台帳の人口・世帯数・人口動態 | [resident-registry.md](docs/resident-registry.md) |
| `economic_census` | 経済センサス‐活動調査 | [economic-census.md](docs/economic-census.md) |
| `economic_structure` | 経済構造実態調査 | [economic-structure.md](docs/economic-structure.md) |
| `enterprise_activity` | 経済産業省企業活動基本調査 | [enterprise-activity.md](docs/enterprise-activity.md) |
| `household` | 家計調査 | [household.md](docs/household.md) |
| `labor` | 労働力調査 | [labor.md](docs/labor.md) |
| `manufacture` | 工業統計調査 | [manufacture.md](docs/manufacture.md) |
| `migration` | 住民基本台帳人口移動報告 | [migration.md](docs/migration.md) |
| `local_finance` | 地方財政状況調査 | [local-finance.md](docs/local-finance.md) |
| `retail_price` | 小売物価統計調査 | [retail-price.md](docs/retail-price.md) |
| `welfare_facility` | 社会福祉施設等調査 | [welfare-facility.md](docs/welfare-facility.md) |
| `kaigo_service` | 介護サービス施設・事業所調査 | [kaigo-service.md](docs/kaigo-service.md) |
| `kaigo_insurance` | 介護保険事業状況報告 | [kaigo-insurance.md](docs/kaigo-insurance.md) |
| `medical_facility` | 医療施設調査 | [medical-facility.md](docs/medical-facility.md) |
| `employment_structure` | 就業構造基本調査 | [employment-structure.md](docs/employment-structure.md) |
| `wage_structure` | 賃金構造基本統計調査 | [wage-structure.md](docs/wage-structure.md) |
| `private_salary` | 民間給与実態統計調査 | [private-salary.md](docs/private-salary.md) |
| `school` | 学校基本調査 | [school.md](docs/school.md) |
| `school_health` | 学校保健統計調査 | [school-health.md](docs/school-health.md) |
| `building_starts` | 建築着工統計調査 | [building-starts.md](docs/building-starts.md) |
| `construction` | 建設総合統計・建設工事受注動態統計調査 | [construction.md](docs/construction.md) |
| `rail_transport` | 鉄道輸送統計調査 | [rail-transport.md](docs/rail-transport.md) |
| `port` | 港湾調査 | [port.md](docs/port.md) |
| `housing_survey` | 住宅・土地統計調査 | [housing-survey.md](docs/housing-survey.md) |
| `crop` | 作物統計調査（野菜） | [vegetable-production.md](docs/vegetable-production.md) |
| `household_structure` | 全国家計構造調査 | [household-structure.md](docs/household-structure.md) |
| `vital_statistics` | 人口動態調査 | [vital-statistics.md](docs/vital-statistics.md) |

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
- `code.municipality` などの 5 桁の地域コードは、全国地方公共団体コード（6 桁、チェックディジット付き）とは別の体系です。`lg_code` や `address_br` と結合するときは桁と体系を統一してください。
- 国勢調査の小地域の `area` は `boundary.small_area` の `key_code` と同じ体系です。小地域の統計を地図に載せるときはこの列で結合します。

## 更新

```bash
uv sync
bash scripts/build.sh
```
