-- 250mメッシュの人口総数が、1次メッシュごとに1kmメッシュの人口総数と一致することを検証する。
-- 250mメッシュは手元でだけロードする (load_local_mesh.py) ので、1次メッシュの一部だけ
-- 取得に失敗しても、CI では気づく機会が無い。区画の欠けも値のずれも、ここで落とす。
-- 秘匿・合算の行も含めて合計する。人口総数は秘匿のメッシュにも入っており、
-- すべての行の合計が総人口になる (1kmメッシュも同じ)。
-- source がまだ無いカタログ (初回のロード前・空から作り直した直後) では検査しない。
-- 0 行の view と1kmメッシュを比べて落とすと、他のテーブルの更新まで止まるため。
{% if local_mesh_source_loaded('mesh_population_250m') %}
WITH m250 AS (
    SELECT mesh1_code, SUM(value) AS population
    FROM {{ ref('population_mesh_250m') }}
    WHERE cat01 = '0010'
    GROUP BY 1
),
m1k AS (
    SELECT SUBSTR(area, 1, 4) AS mesh1_code, SUM(TRY_CAST(value AS DOUBLE)) AS population
    FROM {{ ref('raw_mesh_population') }}
    WHERE cat01 = '0010'
    GROUP BY 1
)
SELECT mesh1_code, m1k.population AS population_1km, m250.population AS population_250m
FROM m1k
FULL OUTER JOIN m250 USING (mesh1_code)
WHERE m250.population IS DISTINCT FROM m1k.population
{% else %}
SELECT NULL AS mesh1_code WHERE FALSE
{% endif %}
