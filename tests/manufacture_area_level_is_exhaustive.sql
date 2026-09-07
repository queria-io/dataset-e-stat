-- municipality_industry の area_level が全行に付き、粒度が日本全域を1回ずつ覆うことを
-- 検証する。結果が0行ならテスト成功。
--
-- この表の地域軸は年で形が変わる。2012年までは area 軸に5桁のコードが level 2/3/4 で、
-- 2013年以降は cat03 軸に都道府県だけ2桁のコードが level 1/2/3 で入る。さらに2013年
-- 以降のメタ情報は、東京特別区(13100)と23区の親コードを直前に並ぶ別の県の町(12463)に
-- している。level と親コードをそのまま信じると東京が丸ごと落ちるので、コードから
-- 振り分けている。e-Stat 側がコードの振り方を変えると、行数も値も変わらないまま
-- 粒度だけがずれる。
--
-- 都道府県は毎年47。市区町村の和が都道府県に一致することは
-- manufacture_totals_are_consistent.sql で見る。

SELECT '粒度が付いていない行がある' AS violation, CAST(survey_year AS VARCHAR) AS detail
FROM {{ ref('municipality_industry') }}
WHERE area_level IS NULL OR area_level NOT IN ('prefecture', 'municipality', 'ward')
UNION ALL
-- 2013年以降の都道府県は2桁で入るので stg で5桁にそろえている。正規化が抜けると
-- 都道府県だけコードの形が変わり、標準地域コードとして結合できなくなる。
SELECT '標準地域コードの形になっていない地域がある', area
FROM {{ ref('municipality_industry') }}
WHERE area NOT SIMILAR TO '[0-9]{5}'
UNION ALL
SELECT '市区町村の親が都道府県として存在しない', m.area
FROM {{ ref('municipality_industry') }} m
LEFT JOIN {{ ref('municipality_industry') }} p
    ON p.survey_year = m.survey_year
    AND p.area = m.parent_area
    AND p.area_level = 'prefecture'
    AND p.industry_code = '00'
WHERE m.area_level = 'municipality' AND m.industry_code = '00' AND p.area IS NULL
UNION ALL
SELECT '都道府県が47件でない年がある', CAST(survey_year AS VARCHAR)
FROM (
    SELECT survey_year, COUNT(DISTINCT area) AS n
    FROM {{ ref('municipality_industry') }}
    WHERE area_level = 'prefecture'
    GROUP BY survey_year
)
WHERE n <> 47
UNION ALL
-- 23区の合計にあたる東京特別区(13100)は市区町村の粒度に置く。ここが ward に落ちると
-- 市区町村だけを足したときに東京が欠ける。
SELECT '東京特別区(13100)が市区町村の粒度に無い年がある', CAST(survey_year AS VARCHAR)
FROM (
    SELECT survey_year,
        COUNT(*) FILTER (WHERE area = '13100' AND area_level = 'municipality') AS n
    FROM {{ ref('municipality_industry') }}
    WHERE industry_code = '00'
    GROUP BY survey_year
)
WHERE n <> 1
UNION ALL
-- 区の親は必ず市区町村の粒度にある。親が誰かまでは見ない（前3桁から親を作ると川崎市・
-- 相模原市・浜松市・堺市・福岡市の区が別の市にぶら下がるが、親そのものは実在するので
-- ここでは落ちない）。付け替わりは manufacture_totals_are_consistent.sql の
-- 「政令指定都市 <> 区の和」が拾う。
SELECT '区の親が市区町村の粒度に無い', w.area
FROM {{ ref('municipality_industry') }} w
LEFT JOIN {{ ref('municipality_industry') }} p
    ON p.survey_year = w.survey_year
    AND p.area = w.parent_area
    AND p.area_level = 'municipality'
    AND p.industry_code = '00'
WHERE w.area_level = 'ward' AND w.industry_code = '00' AND p.area IS NULL
