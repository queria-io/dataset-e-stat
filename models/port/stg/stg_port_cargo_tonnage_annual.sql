{# 港湾調査（年報）甲種港湾の海上出入貨物トン数を、港 × 輸移出入 × 年の1行にする。

   原典は輸送形態（cat03: 計・一般・自動車航送船）と T/S（cat02: 計・内T/S）を軸に持つが、
   セルが無いところは行ごと出てこない。とくに輸送形態の計（100）は、2023年の甲種港湾で
   一般の行がある165港のうち80港にしか無い。計で絞ると港が半分落ちるので、輸送形態を列に
   広げ、計の行が無いときは一般と自動車航送船の和で補う。計の行があるときは原典の値を使う
   （小樽・佐伯などで一般が「-」なのに計が自動車航送船より大きい年があり、和で置き換えると
   値が変わる）。T/S は一般の内数としてしか出てこないので、計（cat02=100）と分けて列にする。

   港（cat04）は2段で、都道府県（level=2、コードの末尾3桁が000）と港（level=3、
   「北海道_稚内」のように県名と港名を _ でつないだ名前）が同じ軸に並ぶ。県の行は、その県の
   港の和と全年・全区分で一致する（2018年を除いて実測）。

   2018年は原典の値が崩れているので落とす。名古屋の計が2,272,043トン（前後の年は約1.9億トン）、
   自動車航送船が63,860,975トン（前後の年は約400万トン）になっているなど、10県で県の行が
   港の和と合わず、甲種港湾の総計も前後の年から外れる。 #}
WITH source AS (
    SELECT cat01, cat01_metadata, cat02, cat03, cat04, cat04_metadata, time, value
    FROM {{ ref('raw_port_cargo_tonnage_annual') }}
    WHERE tab = '120'
        AND time <> '2018000000'
),

pivoted AS (
    SELECT
        cat04,
        ANY_VALUE(cat04_metadata) AS cat04_metadata,
        cat01,
        ANY_VALUE(cat01_metadata) AS cat01_metadata,
        time,
        COUNT(*) FILTER (WHERE cat02 = '100' AND cat03 = '100') AS total_rows,
        MAX(value) FILTER (WHERE cat02 = '100' AND cat03 = '100') AS total_tons,
        MAX(value) FILTER (WHERE cat02 = '100' AND cat03 = '110') AS general_tons,
        MAX(value) FILTER (WHERE cat02 = '100' AND cat03 = '120') AS ferry_tons,
        MAX(value) FILTER (WHERE cat02 = '110' AND cat03 = '110') AS transshipment_tons
    FROM source
    GROUP BY cat04, cat01, time
)

SELECT
    cat04 AS area_code,
    TRY_CAST(cat04_metadata->>'$.level' AS INTEGER) AS area_level,
    SUBSTR(cat04, 1, 2) AS prefecture_code,
    SPLIT_PART(cat04_metadata->>'$.name', '_', 1) AS prefecture_name,
    CASE WHEN cat04_metadata->>'$.level' = '3'
        THEN SUBSTR(cat04_metadata->>'$.name', STRPOS(cat04_metadata->>'$.name', '_') + 1)
    END AS port_name,
    cat01 AS flow_code,
    cat01_metadata->>'$.name' AS flow_name,
    time,
    TRY_CAST(SUBSTR(time, 1, 4) AS INTEGER) AS year,
    CAST(CASE
        WHEN total_rows > 0 THEN total_tons
        WHEN general_tons IS NOT NULL OR ferry_tons IS NOT NULL
            THEN COALESCE(general_tons, 0) + COALESCE(ferry_tons, 0)
    END AS BIGINT) AS cargo_tons,
    total_rows = 0 AND (general_tons IS NOT NULL OR ferry_tons IS NOT NULL) AS cargo_tons_is_derived,
    CAST(general_tons AS BIGINT) AS general_tons,
    CAST(ferry_tons AS BIGINT) AS ferry_tons,
    CAST(transshipment_tons AS BIGINT) AS transshipment_tons
FROM pivoted
