{# census_municipality (令和2年) の令和7年版。列は同じで、5年前の比べる相手だけが
   2015年から 2020年に替わる(population_2020 / households_2020)。
   3 つの統計表は area の分類が一致する(4,082 地域)ので、地域 1 行の横持ちに開く。 #}
WITH population AS (
    SELECT
        area,
        ANY_VALUE(area_name) AS area_name,
        ANY_VALUE(area_level) AS area_level,
        ANY_VALUE(parent_area) AS parent_area,
        MAX(value) FILTER (WHERE cat01 = '0') AS population,
        MAX(value) FILTER (WHERE cat01 = '1') AS population_male,
        MAX(value) FILTER (WHERE cat01 = '2') AS population_female
    FROM {{ ref('stg_census_2025_municipality_population') }}
    GROUP BY area
),

household AS (
    SELECT
        area,
        MAX(value) FILTER (WHERE tab = '2025_13' AND cat01 = '0') AS households,
        MAX(value) FILTER (WHERE tab = '2025_13' AND cat01 = '1') AS households_general,
        MAX(value) FILTER (WHERE tab = '2025_13' AND cat01 = '2') AS households_institutional,
        MAX(value) FILTER (WHERE tab = '2025_22' AND cat01 = '0') AS household_members,
        MAX(value) FILTER (WHERE tab = '2025_22' AND cat01 = '1') AS household_members_general,
        MAX(value) FILTER (WHERE tab = '2025_22' AND cat01 = '2') AS household_members_institutional
    FROM {{ ref('stg_census_2025_municipality_household') }}
    GROUP BY area
),

change AS (
    SELECT
        area,
        CAST(MAX(value) FILTER (WHERE tab = '2025_03') AS BIGINT) AS population_2020,
        CAST(MAX(value) FILTER (WHERE tab = '2025_15') AS BIGINT) AS households_2020,
        CAST(MAX(value) FILTER (WHERE tab = '2025_34') AS BIGINT) AS population_change_5y,
        MAX(value) FILTER (WHERE tab = '2025_35') AS population_change_rate_5y,
        CAST(MAX(value) FILTER (WHERE tab = '2025_36') AS BIGINT) AS household_change_5y,
        MAX(value) FILTER (WHERE tab = '2025_37') AS household_change_rate_5y,
        MAX(value) FILTER (WHERE tab = '2025_46') AS sex_ratio,
        MAX(value) FILTER (WHERE tab = '2025_47') AS area_km2,
        MAX(value) FILTER (WHERE tab = '2025_48') AS population_density
    FROM {{ ref('stg_census_2025_municipality_change') }}
    GROUP BY area
)

SELECT
    p.area,
    p.area_name,
    p.area_level,
    p.parent_area,
    p.population,
    p.population_male,
    p.population_female,
    h.households,
    h.households_general,
    h.households_institutional,
    h.household_members,
    h.household_members_general,
    h.household_members_institutional,
    c.population_2020,
    c.households_2020,
    c.population_change_5y,
    c.population_change_rate_5y,
    c.household_change_5y,
    c.household_change_rate_5y,
    c.sex_ratio,
    c.area_km2,
    c.population_density
FROM population p
LEFT JOIN household h ON p.area = h.area
LEFT JOIN change c ON p.area = c.area
