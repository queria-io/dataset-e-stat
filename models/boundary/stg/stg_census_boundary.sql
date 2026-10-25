{# 令和2年国勢調査 小地域(町丁・字等)の境界。商圏分析は、商圏の周り数 km の町丁目だけを
   x_code・y_code の範囲や key_code の前方一致で引く。key_code 順に並べると市区町村ごとに
   場所がまとまるので、行グループの統計で読む範囲を絞れる。
   形 (geometry) が 1 行あたり約 1.3KB あり、既定のままだと 23.2 万行が 4 つの行グループ
   (1 つ 65〜79MB) に入る。どこを引いても行グループを丸ごと読むことになるので、4,096 行に
   切る。設定はスキーマに付ける。dbt は __dbt_tmp の名前で書いてから改名するので、
   テーブルに付けると書き出しに効かない。この設定は catalog に残り、boundary スキーマの
   ほかの表 (raw_census_boundary・メッシュ境界) にも効く。hook を消しても元には戻らない。 #}
{{ config(
    pre_hook="CALL {{ this.database }}.set_option('parquet_row_group_size', 4096, schema => '{{ this.schema }}')"
) }}
SELECT
    KEY_CODE AS key_code,
    PREF AS prefecture_code,
    PREF_NAME AS prefecture_name,
    CITY AS city_code,
    CITY_NAME AS city_name,
    S_NAME AS area_name,
    HCODE AS hcode,
    KIGO_E AS kigo_e,
    KIGO_D AS kigo_d,
    KIGO_I AS kigo_i,
    AREA_MAX_F AS area_max_f,
    JINKO AS jinko,
    SETAI AS setai,
    X_CODE AS x_code,
    Y_CODE AS y_code,
    AREA AS area_m2,
    geom AS geometry
FROM {{ ref('raw_census_boundary') }}
WHERE geom IS NOT NULL
ORDER BY key_code
