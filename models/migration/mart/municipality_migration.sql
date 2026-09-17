{# 表章項目（転入・転出・転入超過）は表ごとに固定で3つしかないので、縦持ちのままにせず
   地域×年×性別×国籍 で1行の横持ちに開く。縦持ちだと3つの測定項目が同じ列に並び、
   絞り込みを忘れた合計が黙って通る。

   地域名・階層・親コードもキーに入れて集約する。同じ地域・同じ年の3つの表章は同じ
   統計表の同じメタ情報から来るので1行に畳まれるが、上流でメタ情報がずれたときは
   行が2つに割れて migration_keys_are_unique が落ちる。ANY_VALUE で黙らせない。 #}
SELECT
    area,
    area_name,
    area_level,
    parent_area,
    year,
    sex_code,
    sex,
    nationality_code,
    nationality,
    MAX(value) FILTER (WHERE measure = 'inflow') AS inflow,
    MAX(value) FILTER (WHERE measure = 'outflow') AS outflow,
    MAX(value) FILTER (WHERE measure = 'net_inflow') AS net_inflow
FROM {{ ref('stg_migration_municipality') }}
GROUP BY area, area_name, area_level, parent_area, year,
    sex_code, sex, nationality_code, nationality
