{# 法人企業統計調査の時系列データを、対象業種の範囲（scope）ごとの表から1つに積む。

   どの表も cat01=調査項目・cat02=業種・cat03=資本金規模・time の4軸だが、調査項目の
   コードは表ごとに振られている（001 は原数値の表では母集団、季節調整値の表では売上高）。
   scope を列に残し、項目は scope の中でだけ比べられるようにする。

   tables は (raw モデル名, scope, scope_name, seasonally_adjusted) の並び。
   UNION は列を明示して積む。BY NAME に頼ると、片方の表に e-Stat が軸を足したときに
   列が入れ替わったまま通ってしまう。

   単位は値に付いた unit を使う。季節調整値のソフトウェアを含む設備投資（005）だけは値にも
   メタ情報にも単位が無い（空文字）ので、ほかの季節調整値の項目と同じ百万円で補う。 #}
{% macro e_stat_corporate_finance_stg(tables, quarterly) %}
{% for model, scope, scope_name, seasonally_adjusted in tables %}
SELECT
    '{{ scope }}' AS scope,
    '{{ scope_name }}' AS scope_name,
    {% if quarterly %}{{ seasonally_adjusted }} AS seasonally_adjusted,
    {% endif %}cat01 AS item_code,
    cat01_metadata->>'$.name' AS item,
    COALESCE(NULLIF(unit, ''), NULLIF(cat01_metadata->>'$.unit', ''), '百万円') AS unit,
    cat02 AS industry_code,
    cat02_metadata->>'$.name' AS industry_name,
    cat03 AS size_code,
    cat03_metadata->>'$.name' AS size_name,
    time,
    {% if quarterly %}regexp_replace(time_metadata->>'$.name', '\s', '', 'g') AS time_name,
    CAST(substr(time, 1, 4) AS INTEGER) AS year,
    CAST(substr(time, 5, 1) AS INTEGER) AS quarter,
    CAST(substr(time, 1, 4) AS INTEGER) - CASE WHEN substr(time, 5, 1) = '1' THEN 1 ELSE 0 END AS fiscal_year,
    {% else %}time_metadata->>'$.name' AS time_name,
    CAST(substr(time, 1, 4) AS INTEGER) AS fiscal_year,
    {% endif %}value
FROM {{ ref(model) }}
{% if not loop.last %}
UNION ALL
{% endif %}
{% endfor %}
{% endmacro %}
