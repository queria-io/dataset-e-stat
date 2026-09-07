{# 工業統計調査 確報 市区町村編 / 地域別「市区町村別、産業中分類別統計」。
   分類は cat01=集計項目、cat02=産業中分類(製造業計 + 中分類24)、area=地域。
   年は統計表そのものが表すので、取得時に survey_year を足してある。

   都道府県コードの桁数が年で違う。2012年までは 01000 の5桁、2013年以降は 01 の2桁で
   入るため、5桁にそろえる。ほかの粒度は年によらず5桁。

   地域と産業の名称は、2013年以降のメタ情報が「【01100】札幌市」のようにコードを
   前置するので外す。

   集計項目 (cat01) は縦持ちのまま残し、mart で項目ごとの列に開く。項目ごとに単位が
   違う (事業所 / 人 / 万円) ため、縦持ちのまま合計すると単位の違う値が混ざる。
   コード体系も2014年までの9桁と2017年以降の8桁で違うので、名称でなくコードで対応を付ける。

   value は原典が「-」(該当数字なし)・「X」(秘匿) を返し、取得時の replaceSpChars=2 で
   空文字になったものが NULL で入る。2つの意味は区別できない。 #}
WITH normalized AS (
    SELECT
        survey_year,
        -- 2013年以降の都道府県コードは2桁。ほかの年・粒度と同じ5桁にそろえる
        CASE WHEN LENGTH(area) = 2 THEN area || '000' ELSE area END AS area,
        area_metadata,
        cat01,
        cat02,
        cat02_metadata,
        value
    FROM {{ ref('raw_manufacture_municipality') }}
)
SELECT
    survey_year,
    area,
    REGEXP_REPLACE(area_metadata->>'$.name', '^【[0-9]+】', '') AS area_name,
    {{ e_stat_manufacture_area_level('area', 'area_metadata') }} AS area_level,
    {{ e_stat_manufacture_parent_area('area', 'area_metadata') }} AS parent_area,
    cat01,
    cat02 AS industry_code,
    REGEXP_REPLACE(cat02_metadata->>'$.name', '^【[0-9]+】', '') AS industry_name,
    TRY_CAST(cat02_metadata->>'$.level' AS INTEGER) AS industry_level,
    value
FROM normalized
