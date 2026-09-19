{# 品目は cat02（銘柄）にあり、cat01 は「データの種別」で 0020（価格）の1値、
   tab も 10（価格）の1値しか無いので stg では落とす。軸が増えたら raw から拾い直す。

   year は time_name の和暦揺れを避けて時間軸コードから切り出す
   （汎用 e_stat_stg_transform は time_name の正規表現から year を取る）。

   item_note / area_note は名称の末尾に付く【…】の注記を、括弧ごと切り出したもの。
   調査を終えた品目・掲載を終えた市が同じ列に残り続けるうえ、【表章単位：割合】の
   ように値の単位が unit 列と食い違う注記もあるので、注記を見ずに集計できない。
   名称の側は原典のまま残す。豊橋市のように注記が2つ並ぶ名称があるので、貪欲一致で
   最初の【から最後の】までを取る（実測: 注記を持つ行はすべてこれで拾える）。 #}
SELECT
    cat02,
    cat02_metadata->>'$.name' AS item_name,
    NULLIF(regexp_extract(cat02_metadata->>'$.name', '【.*】'), '') AS item_note,
    area,
    area_metadata->>'$.name' AS area_name,
    NULLIF(regexp_extract(area_metadata->>'$.name', '【.*】'), '') AS area_note,
    time,
    time_metadata->>'$.name' AS time_name,
    TRY_CAST(substr(time, 1, 4) AS INTEGER) AS year,
    unit,
    TRY_CAST(value AS DOUBLE) AS value
FROM {{ ref('raw_retail_price_annual') }}
