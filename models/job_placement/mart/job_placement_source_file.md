---
$schema: https://queria.io/schemas/table/v1.json
table: job_placement.source_file
title: 一般職業紹介状況の取得ファイル
description: |-
  e-Stat から取得した一般職業紹介状況の都道府県別の労働市場関係指標の Excel（受理地別・就業地別）の一覧です。1 行が 1 つのファイルで、取得した URL・掲載ページ・取得日時と、ファイルの sha256 を持ちます。

  - labor_market_annual・labor_market_monthly の source_sha256 列とこの表の sha256 列で、各行をどのファイルから作ったかを確認できます
  - 同じファイルを取得し直して中身が変わったときは、sha256 ごとに行が分かれます
  - ファイル本体は保存していません。url から取得し直せます
keywords:
  - e-stat
  - 一般職業紹介状況
  - 取得ファイル
sources:
  - path: https://www.e-stat.go.jp/stat-search/files?toukei=00450222
fields:
  - name: url
    title: ファイルの URL
  - name: page_url
    title: 掲載ページの URL
    description: e-Stat でファイルが掲載されていたページの URL。取得できなかったときは NULL
  - name: sha256
    title: sha256
    description: ファイルの sha256
  - name: bytes
    title: バイト数
  - name: media_type
    title: メディアタイプ
    description: 取得したときの応答の Content-Type
  - name: retrieved_at
    title: 取得日時
    description: ファイルを取得した日時（UTC）
  - name: etag
    title: ETag
    description: 取得したときの応答の ETag ヘッダー。無ければ NULL
  - name: last_modified
    title: Last-Modified
    description: 取得したときの応答の Last-Modified ヘッダー。無ければ NULL
themes:
  - labour
---
