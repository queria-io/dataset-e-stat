{# census の area は市区町村(5桁)・町丁・字等(9桁)・その内訳(11桁)が同じ列に縦に
   並んでいて、桁数を数えないと粒度が分からない。5桁は9桁の合計、9桁は11桁の合計に
   あたるため、粒度を揃えずに合計すると二重・三重の計上になる。

   境界データ boundary.small_area の key_code は9桁と11桁のみで、5桁の市区町村行に
   対応する境界は無い。地図に載せるなら small_area / small_area_detail で絞る。 #}
{% macro e_stat_area_level(column) %}
CASE LENGTH({{ column }})
    WHEN 5 THEN 'municipality'
    WHEN 9 THEN 'small_area'
    WHEN 11 THEN 'small_area_detail'
END
{% endmacro %}

{# 市区町村・都道府県別の集計では area が全て5桁で、粒度は桁数から分からない。
   e-Stat のメタ情報が持つ level と parentCode で決まる:
     1 全国 / 2 都道府県 / 4 市・特別区部・特別区 / 5 政令指定都市の区 /
     6 町村 / 7 2000年(平成12年)市区町村
   level=4 には親が都道府県の「市・特別区部」と、親が特別区部(13100)の
   「特別区」の両方が入る。千代田区は level=4 で、政令指定都市の区(level=5)とは
   level が違うのに階層上は同じ位置にある。level だけで分けると特別区が市と
   同じ扱いになり、東京都の人口が二重に乗る。親コードまで見て分ける。 #}
{% macro e_stat_municipality_area_level(metadata_column) %}
CASE {{ metadata_column }}->>'$.level'
    WHEN '1' THEN 'national'
    WHEN '2' THEN 'prefecture'
    WHEN '4' THEN CASE
        WHEN {{ metadata_column }}->>'$.parent_code' LIKE '%000' THEN 'city'
        ELSE 'ward'
    END
    WHEN '5' THEN 'ward'
    WHEN '6' THEN 'town_village'
    WHEN '7' THEN 'former_municipality'
END
{% endmacro %}

{# 経済センサスの産業横断的集計は area の level の振り方が国勢調査と違う。
   全国と都道府県が同じ level=1 で、level=2 が市・特別区部・町村、level=3 が
   政令指定都市の行政区・特別区・境界未定地域にあたる。
   日本全域をちょうど1回覆うのは level=1 の都道府県だけ、または level=2 の全部で、
   level=3 は level=2 の内訳。特別区は level=3 で、その親「特別区部」(13100) が
   level=2 に立つため、level=2 だけを取れば東京も1回だけ数えられる。 #}
{% macro e_stat_economic_census_area_level(code_column, metadata_column) %}
CASE
    WHEN {{ code_column }} = '00000' THEN 'national'
    ELSE CASE {{ metadata_column }}->>'$.level'
        WHEN '1' THEN 'prefecture'
        WHEN '2' THEN 'municipality'
        WHEN '3' THEN 'ward'
    END
END
{% endmacro %}

{# 工業統計調査の市区町村編は、年によって地域軸の階層の振り方が違う。
   2012年までは 2 都道府県 / 3 市・特別区部 / 4 町村と政令指定都市の区・特別区、
   2013年以降は 1 都道府県 / 2 市区町村 / 3 政令指定都市の区・特別区。
   2012年までの level=4 は町村と区が同じ階層に混ざるので、level だけでは分けられない。

   親コードの3桁目が 1 なら政令指定都市か特別区部 (コードは 100〜199 がその範囲) で、
   その子は区。町村の親は郡 (3桁目が 3 以上) で、郡はこの表に行として現れない。

   東京の特別区 (13101〜13123) だけは親コードで判定できない。2013年以降のメタ情報は
   東京特別区 (13100) と 23 区の親コードを、直前に並ぶ別の県の町 (12463 安房郡鋸南町) に
   している。都道府県 (level=1) の次に level=3 が来て level=2 を飛ばすため、親を辿る側が
   直前の level=2 を拾っているとみられる。コードで直接判定する。

   東京特別区 (13100) は 23 区の合計にあたる行で、市区町村と同じ階層に置く。
   2013年以降は level=3 に入っているが、level で市区町村を絞ると東京が丸ごと欠ける。 #}
{% macro e_stat_manufacture_area_level(code_column, metadata_column) %}
CASE
    WHEN {{ code_column }} LIKE '%000' THEN 'prefecture'
    WHEN {{ code_column }} LIKE '131%' AND {{ code_column }} <> '13100' THEN 'ward'
    WHEN SUBSTR({{ metadata_column }}->>'$.parent_code', 3, 1) = '1' THEN 'ward'
    ELSE 'municipality'
END
{% endmacro %}

{# 1つ上の階層の地域コード。市区町村の親は都道府県で、メタ情報の親コード (2012年までは
   郡、2013年以降は2桁の都道府県コード) は使わない。区の親は政令指定都市、特別区の親は
   東京特別区 (13100)。都道府県の親は無い (この表に全国の行は無い)。 #}
{% macro e_stat_manufacture_parent_area(code_column, metadata_column) %}
CASE
    WHEN {{ code_column }} LIKE '%000' THEN NULL
    WHEN {{ code_column }} LIKE '131%' AND {{ code_column }} <> '13100' THEN '13100'
    WHEN SUBSTR({{ metadata_column }}->>'$.parent_code', 3, 1) = '1'
        THEN {{ metadata_column }}->>'$.parent_code'
    ELSE SUBSTR({{ code_column }}, 1, 2) || '000'
END
{% endmacro %}
