{# 原典の値は百万円で小数4位まで（100円単位）。Excel から浮動小数で読んだ端数を
   その桁に丸めて DECIMAL にする。全国計の行（area = '00000'）は残し、
   prefecture_code を NULL にしておく。 #}
SELECT
    prefecture_code,
    area,
    area_name,
    year,
    month,
    CASE WHEN month >= 4 THEN year ELSE year - 1 END AS fiscal_year,
    CAST(ROUND(total, 4) AS DECIMAL(18, 4)) AS total,
    CAST(ROUND(national_total, 4) AS DECIMAL(18, 4)) AS national_total,
    CAST(ROUND(national_government, 4) AS DECIMAL(18, 4)) AS national_government,
    CAST(ROUND(independent_agency, 4) AS DECIMAL(18, 4)) AS independent_agency,
    CAST(ROUND(government_affiliated, 4) AS DECIMAL(18, 4)) AS government_affiliated,
    CAST(ROUND(local_total, 4) AS DECIMAL(18, 4)) AS local_total,
    CAST(ROUND(prefectural_government, 4) AS DECIMAL(18, 4)) AS prefectural_government,
    CAST(ROUND(municipal_government, 4) AS DECIMAL(18, 4)) AS municipal_government,
    CAST(ROUND(local_public_enterprise, 4) AS DECIMAL(18, 4)) AS local_public_enterprise,
    CAST(ROUND(other, 4) AS DECIMAL(18, 4)) AS other
FROM {{ ref('raw_construction_public_orders_prefecture_monthly') }}
