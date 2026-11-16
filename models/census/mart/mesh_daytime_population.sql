{# 1kmメッシュ別の昼間人口を、市区町村の公表値をメッシュへ按分して作る。

   ■ 考え方

   昼間人口は市区町村までしか公表されていない。ただし公表値には内訳があり、
   実データで次の恒等式が市区町村1,913件のうち1,911件で厳密に成立する
   (残り2件は令和2年時点で存在しない浜松市の新設区で、元データが無い)。

     夜間人口 = A6101 + A6102 + A6103 + A6104 + 不詳
     昼間人口 = A6101 + A6102 + A6105 + A6106 + 不詳

     A6101 従業も通学もしていない人口
     A6102 自市区町村で従業・通学している人口
     A6103 流出人口(県内他市区町村)   A6104 流出人口(他県)
     A6105 流入人口(県内他市区町村)   A6106 流入人口(他県)

   不詳(従業地・通学地が不明な常住者)は昼夜とも同じ値なので、常住地に留まる
   扱いになっている。そこで昼間人口を2つに割り、それぞれ別のウェイトで配る。

     その場に残る人   = A6101 + 不詳                → 夜間人口で按分
     そこで働く・学ぶ人 = A6102 + A6105 + A6106      → 従業者数で按分

   ウェイトは市区町村内で正規化するので、市区町村ごとに合計すると
   A6101 + 不詳 + A6102 + A6105 + A6106 = 公表昼間人口 に厳密に一致する。
   後付けのキャリブレーションは要らない。千代田区で検算すると
   12,064 + 22,282 + 18,510 + 463,702 + 387,222 = 903,780 で公表値と一致する。

   ■ 秘匿処理 — 小地域と扱いが逆なので注意

   メッシュ統計の cat02 は秘匿・合算区分(1無し/2合算/3秘匿)で、名前は小地域集計と
   同じだが中身が違う。小地域集計は cat02=3(秘匿)の行に 0 が入り、実数は
   cat02=2(合算)の地域に含まれる(census_small_area_* の説明を参照)。メッシュ統計は
   逆で、秘匿メッシュも合算先メッシュもそれぞれ実値を持ち、合算先に秘匿分は
   含まれていない。

   根拠(実測):
   - 合算先 53393666 の値は 10。寄せ元の秘匿メッシュ 53393665(4) と 53393676(14)
     の合計は 18 で、合算先が秘匿分を含んでいるなら 10 < 18 となり矛盾する
   - 東京都の全メッシュを cat02 を問わず単純合計すると 14,047,594 となり、
     令和2年国勢調査の東京都人口の公表値と完全に一致する。秘匿分が二重に
     入っていれば公表値を上回る

   よって cat02 を問わず単純に合計してよい。小地域集計と同じつもりで
   cat02=3 を除くと、その分だけ人口を取りこぼす。

   ■ 限界

   - 従業者数は平成28年経済センサス。流入の総量は令和2年の公表値なので、
     ずれるのは市区町村内の配分だけ
   - 従業者数は A～R 全産業(S公務を除く)。官公庁の集積は流入ウェイトに乗らない
   - 通学による流入は学校所在地別の在学者数が公的オープンデータに無いため、
     事業所従業者数のウェイトで代用される
   - 市区町村が引けないメッシュ(中心点がどの町丁・字等にも入らない離島・海上など)は
     昼間人口 = 夜間人口 とする #}
{{ config(materialized='ephemeral') }}

WITH mesh_night AS (
    SELECT
        mesh_code,
        SUM(value) AS nighttime_population
    FROM {{ ref('stg_mesh_population') }}
    WHERE cat01 = '0010'  -- 人口(総数)
    GROUP BY mesh_code
),

mesh_work AS (
    SELECT
        mesh_code,
        SUM(CASE WHEN cat01 = '0200' THEN value END) AS employees,
        SUM(CASE WHEN cat01 = '0010' THEN value END) AS establishments
    FROM {{ ref('stg_mesh_establishment') }}
    WHERE cat01 IN ('0010', '0200')  -- 事業所数 / 従業者数 (A～R全産業)
    GROUP BY mesh_code
),

-- 事業所だけがあって人口0のメッシュ(工業地帯など)を落とさないよう FULL JOIN
mesh AS (
    SELECT
        COALESCE(n.mesh_code, w.mesh_code) AS mesh_code,
        COALESCE(n.nighttime_population, 0) AS nighttime_population,
        COALESCE(w.employees, 0) AS employees,
        COALESCE(w.establishments, 0) AS establishments
    FROM mesh_night AS n
    FULL JOIN mesh_work AS w ON n.mesh_code = w.mesh_code
),

assigned AS (
    SELECT
        m.mesh_code,
        m.nighttime_population,
        m.employees,
        m.establishments,
        c.city_code
    FROM mesh AS m
    LEFT JOIN {{ ref('mesh_municipality') }} AS c ON m.mesh_code = c.mesh_code
),

municipal AS (
    SELECT
        area AS city_code,
        MAX(CASE WHEN cat01 = 'A1101' THEN value END) AS nighttime_official,
        MAX(CASE WHEN cat01 = 'A6101' THEN value END) AS not_commuting,
        MAX(CASE WHEN cat01 = 'A6102' THEN value END) AS commuting_within,
        MAX(CASE WHEN cat01 = 'A6103' THEN value END) AS outflow_in_pref,
        MAX(CASE WHEN cat01 = 'A6104' THEN value END) AS outflow_other_pref,
        MAX(CASE WHEN cat01 = 'A6105' THEN value END) AS inflow_in_pref,
        MAX(CASE WHEN cat01 = 'A6106' THEN value END) AS inflow_other_pref
    FROM {{ ref('stg_municipal_population') }}
    WHERE
        year = 2020
        AND cat01 IN (
            'A1101', 'A6101', 'A6102', 'A6103', 'A6104', 'A6105', 'A6106'
        )
    GROUP BY area
),

control AS (
    SELECT
        city_code,
        -- 残る人 = 従業も通学もしていない人口 + 従業地・通学地「不詳」
        not_commuting
        + (
            nighttime_official
            - (not_commuting + commuting_within + outflow_in_pref + outflow_other_pref)
        ) AS staying,
        -- 昼間そこで従業・通学する人
        commuting_within + inflow_in_pref + inflow_other_pref AS commuting_in
    FROM municipal
    WHERE
        nighttime_official IS NOT NULL
        AND not_commuting IS NOT NULL
        AND commuting_within IS NOT NULL
        AND outflow_in_pref IS NOT NULL
        AND outflow_other_pref IS NOT NULL
        AND inflow_in_pref IS NOT NULL
        AND inflow_other_pref IS NOT NULL
),

weighted AS (
    SELECT
        a.*,
        SUM(a.nighttime_population) OVER (PARTITION BY a.city_code) AS city_night_sum,
        SUM(a.employees) OVER (PARTITION BY a.city_code) AS city_employee_sum
    FROM assigned AS a
)

SELECT
    w.mesh_code,
    w.city_code,
    w.nighttime_population,
    w.employees,
    w.establishments,
    CASE
        -- 市区町村が引けない、または公表値の内訳が無い場合は動かさない
        WHEN c.city_code IS NULL THEN w.nighttime_population
        ELSE
            COALESCE(
                c.staying * w.nighttime_population / NULLIF(w.city_night_sum, 0), 0
            )
            + CASE
                -- 市区町村内に事業所が1つも無いときは従業者数で按分できないので
                -- 夜間人口で配る (自宅従業などが残るため)
                WHEN w.city_employee_sum > 0
                    THEN c.commuting_in * w.employees / w.city_employee_sum
                ELSE COALESCE(
                    c.commuting_in * w.nighttime_population
                    / NULLIF(w.city_night_sum, 0), 0
                )
            END
    END AS daytime_population
FROM weighted AS w
LEFT JOIN control AS c ON w.city_code = c.city_code
