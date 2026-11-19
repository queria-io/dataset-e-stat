---
$schema: https://queria.io/schemas/table/v1.json
table: census.population_mesh_250m
title: 250mメッシュ別 人口・世帯（令和2年国勢調査）
description: |-
  令和2年国勢調査の250mメッシュ別の人口と世帯を、年齢区分・世帯人員・家族類型など50区分で持つテーブルです。

  - 秘匿のメッシュは年齢などの内訳が0で、その人数は合算先のメッシュに含まれます。範囲で合計してから使ってください
  - mesh_code で boundary.mesh_250m と、mesh_1km_code で boundary.mesh_1km と結合します
keywords:
  - e-stat
  - 国勢調査
  - メッシュ
  - 地域メッシュ統計
  - 人口
  - 年齢
  - 世帯
  - GIS
temporal_coverage: {start: "2020", end: "2020"}
sources:
  - path: https://www.e-stat.go.jp/
fields:
  - name: mesh_code
    title: 250mメッシュコード（10桁）
    description: 4分の1地域メッシュのコード（10桁）。上8桁が3次メッシュ（1km）、9桁目が2分の1地域メッシュ（500m）、10桁目が4分の1地域メッシュ（250m）の位置
    semantic: {role: entity, name: mesh}
  - name: mesh_1km_code
    title: 3次メッシュコード（8桁）
    description: mesh_code の上8桁。境界データ mesh_1km の mesh_code と結合できる
    semantic: {role: entity, name: mesh}
  - name: mesh1_code
    title: 1次メッシュコード（4桁）
    description: mesh_code の上4桁。統計表の配布単位で、約80km四方
    semantic: {role: dimension}
  - name: cat01
    title: 区分コード
    description: 年齢別人口・世帯の種類別世帯数等の区分コード（4桁）。0010 人口総数、0040 0〜14歳、0100 15〜64歳、0130 18歳以上、0160 20歳以上、0190 65歳以上、0220 75歳以上、0310 外国人、0340 世帯総数など50区分。総数と内訳が同じ列に並ぶので、cat01 を絞らずに value を合計すると重複する
  - name: category
    title: 区分名
    description: cat01 に対応する区分名（「人口（総数）」「１８歳以上人口　総数」など）
  - name: cat02
    title: 秘匿・合算区分コード
    description: 1=無し、2=合算、3=秘匿。秘匿のメッシュは年齢などの内訳が0で、その人数は合算先（cat02=2）のメッシュの内訳に含まれる
  - name: suppression
    title: 秘匿・合算区分名
    description: cat02 に対応する区分名（無し／合算／秘匿）
  - name: unit
    title: 単位
    description: 人または世帯
  - name: value
    title: 値
    description: 人口（人）または世帯数（世帯）。人口総数と世帯総数はすべての行を合計すると全国・地域の総数に一致する
themes: [population]
---

# 250mメッシュ別 人口・世帯

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| population_mesh_250m | 250mメッシュ（4分の1地域メッシュ）別の人口と世帯（50区分・縦持ち） | mesh_code / mesh_1km_code / cat01 / category / cat02 / value |

令和2年国勢調査の地域メッシュ統計「人口及び世帯」の 250m メッシュ版です。年齢区分
（0〜14歳・15〜64歳・18歳以上・20歳以上・65歳以上・75歳以上など）、外国人人口、
世帯人員別・家族類型別の世帯数など 50 区分を、`cat01` の区分ごとに 1 行で持ちます。
町丁目の年齢は 5 歳階級でしか区切れませんが、この表は 18 歳以上人口を持つので、
17 歳以下・18〜64 歳を出せます。全国で約 5,800 万行あります。

`mesh_code` は 10 桁で、上 8 桁（`mesh_1km_code`）が 3 次メッシュ（1km）のコードです。
境界データ mesh_250m と `mesh_code` で、mesh_1km と `mesh_1km_code` で結合できます。

## 秘匿と合算

`cat02` が 3（秘匿）のメッシュには、人口総数・男女別・世帯総数・一般世帯数だけが入り、
年齢などの内訳は 0 です。その人数は、2（合算）のメッシュの内訳に足し込まれています。
そのため合算のメッシュでは、内訳の合計が人口総数を上回ることがあります。

- 範囲で合計するときは、秘匿・合算の行も含めてそのまま足せば正しい値になります。
  人口総数をすべての行で合計すると、全国の総人口 126,146,099 人に一致します
- 1 メッシュごとに内訳を引き算する（17 歳以下 = 人口総数 − 18 歳以上 など）と、
  秘匿・合算のメッシュでずれます。`cat02 = '1'` のメッシュに絞るか、範囲で合計してから
  引き算してください

## 手元でだけ取り込むテーブル

このテーブルは毎日の更新（CI）では取り込みません。量が多く、CI のメモリに収まらないためです。
CI は前回ロードした分を参照するビューを作り直すだけです。ロードした分がカタログに無いとき
（カタログを空から作り直した直後など）は、0 行のまま公開されます。そのときは、手元で
次の 2 つを順に回して取り込み直します。

```bash
# 1. e-Stat から取得して data/mesh/ に保存する。2〜3 時間かかる。止まっても続きから回せる
uv run --env-file .env python load_local_mesh.py fetch
# 2. 保存した分をロードし、250m のモデルだけビルドして公開する。数分で終わる
#    fdl は CI と同じく最新に上げてから回す
uv lock --upgrade-package fdl-cli && uv sync
FDL_TOKEN=... scripts/build.sh --env-file .env python load_local_mesh.py
```

2 は CI の Sync が走っていないときに回します。scripts/build.sh は始めた時点の公開バージョンから
作るので、途中で CI が公開すると fdl push が断られます。そのときは 2 だけ
回し直せば済みます。

出典: 総務省統計局 令和2年国勢調査に関する地域メッシュ統計。
https://www.e-stat.go.jp/

## 補足: census.population_mesh_1km

令和2年国勢調査の地域メッシュ統計のうち、1kmメッシュ（3次メッシュ）別の人口と世帯を縦持ちで収録する。
cat01 が区分で、0010 が人口総数。
cat02 は秘匿・合算区分だが、人口総数（0010）の扱いは町丁・字等の集計と逆になる。
人口総数は、秘匿のメッシュも合算先のメッシュもそれぞれ実値を持ち、合算先に秘匿分は含まれない。
人口総数を cat02 を問わず合計すると、全国の総人口に一致する。
これを確かめたのは人口総数だけで、年齢などの内訳は確かめていない。
250mメッシュ（population_mesh_250m）では秘匿のメッシュの内訳が0で、その人数が合算先のメッシュの内訳に足し込まれている。

## 補足: census.population_mesh_250m

範囲で合計すれば正しいが、1メッシュごとに内訳を引き算すると秘匿・合算のメッシュでずれる。
