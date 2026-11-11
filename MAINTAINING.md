# 保守の手順

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

