{# 鉄道輸送統計調査の旅客数量（業態別・月次）を、業態 × 定期・定期外 × 月の1行にする。

   業態（cat02）は3段で、計（160, level=1）・ＪＲ旅客会社（100）と民鉄（120）（level=2）・
   その内訳（level=3）が同じ軸に並ぶ。新幹線（110）はＪＲ旅客会社の内数、大手・中小・公営
   （130〜150）は民鉄の内訳。計はＪＲ旅客会社と民鉄の和に、民鉄は大手・中小・公営の和に
   一致する（全月で実測）。段と親を列に残し、足すときに二重に数えないようにする。
   定期・定期外（cat01）も計（100）と内訳（110・120）が並ぶ。内訳の和は千人の丸めで
   計と最大9千人ずれる。 #}
WITH source AS (
    SELECT cat01, cat01_metadata, cat02, cat02_metadata, time, time_metadata, value
    FROM {{ ref('raw_rail_transport_passengers_monthly') }}
    WHERE tab = '110'
)

SELECT
    cat02 AS operator_type_code,
    cat02_metadata->>'$.name' AS operator_type_name,
    TRY_CAST(cat02_metadata->>'$.level' AS INTEGER) AS operator_type_level,
    cat02_metadata->>'$.parent_code' AS operator_type_parent_code,
    cat01 AS ticket_type_code,
    cat01_metadata->>'$.name' AS ticket_type_name,
    time,
    time_metadata->>'$.name' AS time_name,
    TRY_CAST(SUBSTR(time, 1, 4) AS INTEGER) AS year,
    TRY_CAST(SUBSTR(time, 9, 2) AS INTEGER) AS month,
    CAST(value AS BIGINT) AS passengers
FROM source
