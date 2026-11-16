-- 都道府県の名前を正式名にそろえる。
--
-- 都道府県は 2023 年調査まで「青森」、2024 年調査から「青森県」で入る。接尾辞を
-- 補って code.municipality_name の pref_name にそろえる。東京・大阪・京都は「都」
-- 「府」で終わるので、末尾 1 文字で判定する前に名指しで拾う。
SELECT
    survey_year,
    CASE
        WHEN area_kind <> 'prefecture' THEN area_name
        WHEN area_name = '東京' THEN '東京都'
        WHEN area_name IN ('大阪', '京都') THEN area_name || '府'
        WHEN right(area_name, 1) IN ('都', '道', '府', '県') THEN area_name
        ELSE area_name || '県'
    END AS area_name,
    area_kind,
    service_category,
    service_type,
    value
FROM {{ ref('raw_kaigo_service_establishment') }}
