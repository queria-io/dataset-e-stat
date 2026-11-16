{{ config(materialized='table', alias='stg_item_lookup') }}

{#
  mart のビューが item_name / unit / 上位項目を引くための、item_code で一意な参照表。

  item_catalog は「どの統計表にその項目が載っているか」を表すため、同じ item_code が
  掲載統計表の数だけ（最大3行）存在する。mart のビューがこれを直接 LEFT JOIN していた
  ため、観測値1行が最大3行に増えていた。SSDS の 22 マートのうち 4,934 の
  (テーブル, cat01) 組のうち 1,657 組がこの掛け算の影響を受けていた。

  item_code ごとに unit が食い違う例は無く、item_name が食い違うのは 5,377 件中 8 件
  （全角/半角括弧などの表記ゆれ）のみ。stats_data_id の小さい統計表の表記を採る。

  上位項目は桁位置で決まる。総務省の定義では項目符号は
  分野1文字 + 大分類1桁 + 小分類1桁 + 項目2桁 = 5桁 で、その下に副区分が付く。
  https://www.stat.go.jp/data/ssds/2.html

      A1101      総人口          （項目 = 5桁）
      A110101    総人口（男）    （副区分。親は先頭5桁）

  副区分は1階層しかないので、5桁を超えるコードの親は必ず先頭5桁になる。
  item_catalog の level / parent_code は使えない（level は全て 1、parent_code は
  全て空）ため、ここで導出する。

  親はデータを持たないことがある。定義に「大分類、小分類等の分類項目名（データは
  ない）も併せて記載しています」とあるとおりで、A1601（未婚人口）のように副区分
  だけが公開されている系統が 621 件ある。parent_code が item_code として存在
  しないのは異常ではない。
#}

SELECT
    item_code,
    MIN_BY(item_name, stats_data_id) AS item_name,
    MIN_BY(unit, stats_data_id) AS unit,
    CASE WHEN LENGTH(item_code) > 5 THEN SUBSTR(item_code, 1, 5) END AS parent_code
FROM {{ ref('item_catalog') }}
GROUP BY item_code
