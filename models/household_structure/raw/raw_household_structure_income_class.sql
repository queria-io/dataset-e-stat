{# 2019年全国家計構造調査 家計総合集計 年間収入階級(44区分)別 1世帯当たり1か月間の収入と支出 (0003424577)。
   tab=表章項目、cat01=世帯の種類、cat02=世帯区分、cat03=世帯主の性別、cat04=収支項目、
   cat05=年間収入階級。tables.yml の api_params で総世帯・全世帯・性別平均、消費支出と10大費目、
   付帯値の表章項目に絞って取る。 #}
SELECT
    tab, cat01, cat02, cat03, cat04, cat05, area, time, value,
    cat04_metadata, cat05_metadata, area_metadata
FROM {{ source('estat_source', 'household_structure_income_class') }}
