# 保守の手順

## 手元で1回だけ取り込む統計表（local_tables.yml）

数年に1度しか出ない統計は、毎日の更新（CI）で e-Stat から取り直しません。Sync の時間を
食うためです。`local_tables.yml` に載せた表は手元で1回だけ取得・公開し、CI は公開済みの
元表を読んでビルドするだけです。

```bash
# 1. e-Stat から取得して data/local/<グループ>/ に保存する
uv run --env-file .env python load_local.py fetch census_2025
# 2. CI の Sync が走っていないときに、ロードして対象のモデルだけビルドし、公開する
uv lock --upgrade-package queria && uv sync
QUERIA_TOKEN=... uv run --env-file .env queria sync -- uv run --env-file .env python load_local.py load census_2025
```

`local_tables.yml` の `updated_date` は取り込んだときの e-Stat の更新日です。毎週
Check updates のワークフローが e-Stat の更新日と比べ、変わっていたら issue を立てます。
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

