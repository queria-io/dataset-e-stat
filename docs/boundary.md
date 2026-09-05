---
title: 境界データ（小地域・メッシュ）
order: 18
---

# 町丁・字等別境界データ（small_area）

令和2年国勢調査の町丁・字等別の境界ポリゴンと、人口・世帯数を収録します。テーブルは `e_stat.boundary.small_area`。境界と集計データは `key_code` で結合できる形になっています。

水面調査区は除外、同一 `key_code` に複数境界がある場合は代表（飛び地等を除外）のみを残しています。

## カラム構成

- prefecture_name / city_name / area_name: 都道府県名 / 市区町村名 / 町丁・字等名
- prefecture_code / city_code: 都道府県コード（2桁）/ 都道府県内の市区町村コード（3桁）
- key_code: 図形と集計データのリンクコード
- jinko: 人口
- setai: 世帯数
- area_m2: 面積（図郭による算出値。公式面積とは一致しない）
- x_code / y_code: 代表点の経度 / 緯度（10進）
- geometry: 境界ポリゴン（GEOMETRY 型、CRS: EPSG:4612 JGD2011）

`geometry` は空間型のため、テキストで確認したいときは `ST_AsText(geometry)` を使います。緯度経度だけなら `x_code` / `y_code` が手軽です。

## 1地域につき1行（末端の区画だけ）

`key_code` は町丁・字等が9桁、丁目に分かれている地域はその内訳が11桁です。同じ地域が両方の桁で入ることはなく、末端の区画だけが1行ずつ入っています。だから全行を素直に `SUM` して構いません。

| key_code の桁数 | 行数 | 人口 |
|---------------:|-----:|-----:|
| 9 | 72,371 | 45,312,627 |
| 11 | 148,232 | 80,833,449 |
| 2 | 87 | 0 |

2桁の 87 行は町丁・字等が割り当てられていないポリゴン（合計 27.4 km²）で、名称が空・人口0です。集計に混ぜたくないときは `LENGTH(key_code) > 2` で外します。

この構造は `census` スキーマと違います。census の `area` は市区町村・町丁字・その内訳の3階層すべてを持つので、結合するときは census 側を粒度で絞らないでください。詳しくは[小地域集計](/cookbook/e_stat/census)を参照してください。

## 市区町村別の人口集計

```sql
SELECT city_name, SUM(jinko) AS population, COUNT(*) AS areas
FROM e_stat.boundary.small_area
WHERE prefecture_name = '東京都'
GROUP BY city_name
ORDER BY population DESC
LIMIT 10
```

## 特定の市区町村の町丁別人口

```sql
SELECT area_name, jinko, setai, x_code, y_code
FROM e_stat.boundary.small_area
WHERE city_name = 'つくば市'
ORDER BY jinko DESC
LIMIT 20
```

## 境界ポリゴンを取得（GIS 用途）

```sql
SELECT area_name, jinko, ST_AsText(geometry) AS wkt
FROM e_stat.boundary.small_area
WHERE city_name = 'つくば市'
ORDER BY jinko DESC
LIMIT 5
```

# 1kmメッシュ境界（mesh_1km）

標準地域メッシュ（JIS X 0410）の3次メッシュ（1kmメッシュ）の区画です。テーブルは `e_stat.boundary.mesh_1km`。統計値は持たず、メッシュ単位の統計を地図化するときの器として使います。

- mesh_code: 3次メッシュコード（8桁）。メッシュ統計との結合キー
- mesh1_code / mesh2_code / mesh3_code: 1次（4桁）/ 2次（2桁）/ 3次（2桁）に分解したもの
- geometry: 区画のポリゴン（CRS: EPSG:4612）

1区画は緯度方向30秒・経度方向45秒。陸域を含む1次メッシュ 176 区画分を収録しています。

```sql
-- 1次メッシュ 5339（東京付近）の区画を取り出す
SELECT mesh_code, ST_AsText(geometry) AS wkt
FROM e_stat.boundary.mesh_1km
WHERE mesh1_code = '5339'
LIMIT 5
```
