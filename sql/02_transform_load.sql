-- Cast staging STRING columns to real types, standardise the handful of
-- airline names that only differ by casing/typo (verified by inspecting
-- Airline.value_counts() during data-quality checks: 'Macair' vs 'MacAir',
-- 'virgin Australia' vs 'Virgin Australia' are the same carrier written
-- inconsistently across years — genuine rebrands like 'Skytrans' ->
-- 'Skytrans Australia' are left distinct, since that's a real name change,
-- not a data-entry error), and derive the two rollup flags used everywhere
-- downstream.

INSERT INTO `airline_ontime.flights_monthly`
SELECT
    Route AS route,
    Departing_Port AS departing_port,
    Arriving_Port AS arriving_port,
    CASE TRIM(Airline)
        WHEN 'Macair' THEN 'MacAir'
        WHEN 'virgin Australia' THEN 'Virgin Australia'
        ELSE TRIM(Airline)
    END AS airline,
    DATE(CAST(Year AS INT64), CAST(Month_Num AS INT64), 1) AS month_date,
    CAST(Year AS INT64) AS year,
    CAST(Month_Num AS INT64) AS month_num,
    -- SAFE_CAST (not CAST): Cancellations has 316 blank rows and
    -- Departures_Delayed has 5, verified during data-quality checks. These
    -- become NULL rather than failing the whole load.
    CAST(SAFE_CAST(Sectors_Scheduled AS FLOAT64) AS INT64) AS sectors_scheduled,
    CAST(SAFE_CAST(Sectors_Flown AS FLOAT64) AS INT64) AS sectors_flown,
    CAST(SAFE_CAST(Cancellations AS FLOAT64) AS INT64) AS cancellations,
    CAST(SAFE_CAST(Departures_On_Time AS FLOAT64) AS INT64) AS departures_on_time,
    CAST(SAFE_CAST(Arrivals_On_Time AS FLOAT64) AS INT64) AS arrivals_on_time,
    CAST(SAFE_CAST(Departures_Delayed AS FLOAT64) AS INT64) AS departures_delayed,
    CAST(SAFE_CAST(Arrivals_Delayed AS FLOAT64) AS INT64) AS arrivals_delayed,
    TRIM(Airline) = 'All Airlines' AS is_all_airlines,
    Route = 'All Ports-All Ports' AS is_national_total
FROM `airline_ontime.staging_otp`;
