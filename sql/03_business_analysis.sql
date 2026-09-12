-- Eight business questions, answered entirely in BigQuery SQL (CTEs, RANK(),
-- LAG(), analytic window functions with QUALIFY). Python (see the notebook)
-- only runs these queries and charts the results.
--
-- `is_all_airlines` rows are BITRE's own "All Airlines" rollup per
-- route/month — used whenever a question needs total market capacity
-- without double-counting across carriers. `is_national_total` rows
-- ("All Ports-All Ports") are a nationwide rollup, not a real route, and are
-- excluded from every route-level question.

-- ============================================================
-- Q1. National capacity trend, 2004-2026 (12-month moving average)
-- ============================================================
SELECT
    month_date,
    sectors_flown,
    ROUND(AVG(sectors_flown) OVER (
        ORDER BY month_date ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
    )) AS sectors_flown_12mo_avg
FROM `airline_ontime.flights_monthly`
WHERE is_all_airlines AND is_national_total
ORDER BY month_date;

-- ============================================================
-- Q2. National on-time arrival rate by year, 2015-2025, with year-over-year
--     change (LAG) -- surfaces the 2022 post-reopening reliability crisis
-- ============================================================
WITH yearly AS (
    SELECT
        year,
        ROUND(100.0 * SUM(arrivals_on_time) / NULLIF(SUM(sectors_flown), 0), 1) AS on_time_rate_pct
    FROM `airline_ontime.flights_monthly`
    WHERE is_all_airlines AND NOT is_national_total AND year BETWEEN 2015 AND 2025
    GROUP BY year
)
SELECT
    year,
    on_time_rate_pct,
    ROUND(on_time_rate_pct - LAG(on_time_rate_pct) OVER (ORDER BY year), 1) AS yoy_change_pp
FROM yearly
ORDER BY year;

-- ============================================================
-- Q3. Airline reliability ranking, 2025 (most recent full year)
--     Minimum 1,000 sectors flown so low-volume regional operators with
--     noisy small-sample rates don't distort the ranking.
-- ============================================================
WITH airline_year AS (
    SELECT
        airline,
        SUM(sectors_flown) AS total_flown,
        ROUND(100.0 * SUM(arrivals_on_time) / NULLIF(SUM(sectors_flown), 0), 1) AS on_time_rate_pct
    FROM `airline_ontime.flights_monthly`
    WHERE year = 2025 AND NOT is_all_airlines AND NOT is_national_total
    GROUP BY airline
)
SELECT
    airline,
    total_flown,
    on_time_rate_pct,
    RANK() OVER (ORDER BY on_time_rate_pct DESC) AS reliability_rank
FROM airline_year
WHERE total_flown >= 1000
ORDER BY reliability_rank;

-- ============================================================
-- Q4. Routes with the worst post-COVID capacity recovery
--     2019 (pre-COVID baseline) vs. 2025, min 20 flights/month baseline so
--     the ranking isn't dominated by tiny routes with 1-2 flights/month.
-- ============================================================
WITH route_year AS (
    SELECT route, year, AVG(sectors_flown) AS avg_monthly_flown
    FROM `airline_ontime.flights_monthly`
    WHERE is_all_airlines AND NOT is_national_total AND year IN (2019, 2025)
    GROUP BY route, year
),
pivoted AS (
    SELECT
        route,
        MAX(IF(year = 2019, avg_monthly_flown, NULL)) AS avg_2019,
        MAX(IF(year = 2025, avg_monthly_flown, NULL)) AS avg_2025
    FROM route_year
    GROUP BY route
)
SELECT
    route,
    ROUND(avg_2019, 1) AS avg_monthly_flights_2019,
    ROUND(avg_2025, 1) AS avg_monthly_flights_2025,
    ROUND(100.0 * avg_2025 / avg_2019, 1) AS pct_of_2019_capacity,
    RANK() OVER (ORDER BY avg_2025 / avg_2019 ASC) AS worst_recovery_rank
FROM pivoted
WHERE avg_2019 >= 20 AND avg_2025 IS NOT NULL
ORDER BY pct_of_2019_capacity ASC
LIMIT 10;

-- ============================================================
-- Q5. Routes that grew beyond their 2019 capacity (the domestic leisure
--     travel boom -- same baseline/threshold logic as Q4)
-- ============================================================
WITH route_year AS (
    SELECT route, year, AVG(sectors_flown) AS avg_monthly_flown
    FROM `airline_ontime.flights_monthly`
    WHERE is_all_airlines AND NOT is_national_total AND year IN (2019, 2025)
    GROUP BY route, year
),
pivoted AS (
    SELECT
        route,
        MAX(IF(year = 2019, avg_monthly_flown, NULL)) AS avg_2019,
        MAX(IF(year = 2025, avg_monthly_flown, NULL)) AS avg_2025
    FROM route_year
    GROUP BY route
)
SELECT
    route,
    ROUND(avg_2019, 1) AS avg_monthly_flights_2019,
    ROUND(avg_2025, 1) AS avg_monthly_flights_2025,
    ROUND(100.0 * avg_2025 / avg_2019, 1) AS pct_of_2019_capacity
FROM pivoted
WHERE avg_2019 >= 20 AND avg_2025 IS NOT NULL
ORDER BY pct_of_2019_capacity DESC
LIMIT 10;

-- ============================================================
-- Q6. Routes that existed in 2019 but had vanished entirely by 2025
-- ============================================================
SELECT route
FROM `airline_ontime.flights_monthly`
WHERE is_all_airlines AND NOT is_national_total AND year = 2019
GROUP BY route
EXCEPT DISTINCT
SELECT route
FROM `airline_ontime.flights_monthly`
WHERE is_all_airlines AND NOT is_national_total AND year = 2025
GROUP BY route
ORDER BY route;

-- ============================================================
-- Q7. Market concentration across competitive routes, 2025
--     HHI (Herfindahl-Hirschman Index) per route: sum of each airline's
--     squared market share. Routes below 500 sectors/year excluded --
--     too thin to draw a competition conclusion from.
-- ============================================================
WITH route_airline AS (
    SELECT route, airline, SUM(sectors_flown) AS flown
    FROM `airline_ontime.flights_monthly`
    WHERE year = 2025 AND NOT is_all_airlines AND NOT is_national_total
    GROUP BY route, airline
    HAVING flown > 0
),
shares AS (
    SELECT
        route, airline, flown,
        SUM(flown) OVER (PARTITION BY route) AS route_total,
        COUNT(*) OVER (PARTITION BY route) AS n_airlines
    FROM route_airline
    QUALIFY route_total >= 500
)
SELECT
    route,
    ANY_VALUE(n_airlines) AS n_airlines,
    ROUND(SUM(POW(100.0 * flown / route_total, 2))) AS hhi,
    ROUND(MAX(100.0 * flown / route_total), 1) AS top_airline_share_pct
FROM shares
GROUP BY route
ORDER BY hhi DESC
LIMIT 15;

-- ============================================================
-- Q8. Case study: Bonza's 2024 collapse and its effect on market
--     concentration on the 6 routes it used to fly
-- ============================================================
WITH bonza_routes AS (
    SELECT DISTINCT route
    FROM `airline_ontime.flights_monthly`
    WHERE airline = 'Bonza' AND NOT is_national_total
),
route_airline_year AS (
    SELECT f.route, f.year, f.airline, SUM(f.sectors_flown) AS flown
    FROM `airline_ontime.flights_monthly` f
    JOIN bonza_routes b ON f.route = b.route
    WHERE f.year IN (2023, 2025) AND NOT f.is_all_airlines AND NOT f.is_national_total
    GROUP BY f.route, f.year, f.airline
    HAVING flown > 0
),
shares AS (
    SELECT
        route, year, airline, flown,
        SUM(flown) OVER (PARTITION BY route, year) AS route_total,
        COUNT(*) OVER (PARTITION BY route, year) AS n_airlines
    FROM route_airline_year
)
SELECT
    route,
    year,
    ANY_VALUE(n_airlines) AS n_airlines,
    ANY_VALUE(route_total) AS total_sectors_flown,
    ROUND(SUM(POW(100.0 * flown / route_total, 2))) AS hhi,
    ROUND(MAX(100.0 * flown / route_total), 1) AS top_airline_share_pct
FROM shares
GROUP BY route, year
ORDER BY route, year;
