-- Typed, cleaned table that all analysis in 03_business_analysis.sql runs against.
--
-- Two flag columns let a query choose its own grain without re-deriving it:
--   is_all_airlines   = TRUE for BITRE's own "All Airlines" rollup row
--                        (verified: for a given route/month it equals the sum
--                        of that month's individual-airline rows exactly, e.g.
--                        Adelaide-Brisbane Jun-19: Jetstar 22 + Qantas 103 +
--                        QantasLink 1 + Tigerair 30 + Virgin 102 = 258 =
--                        All Airlines). Per-airline analysis must exclude it,
--                        market-wide totals should use it instead of SUM().
--   is_national_total = TRUE for BITRE's "All Ports-All Ports" rollup row
--                        (a nationwide total, not a real route). Any
--                        route-level analysis must exclude it.

CREATE OR REPLACE TABLE `airline_ontime.flights_monthly` (
    route STRING,
    departing_port STRING,
    arriving_port STRING,
    airline STRING,
    month_date DATE,
    year INT64,
    month_num INT64,
    sectors_scheduled INT64,
    sectors_flown INT64,
    cancellations INT64,
    departures_on_time INT64,
    arrivals_on_time INT64,
    departures_delayed INT64,
    arrivals_delayed INT64,
    is_all_airlines BOOL,
    is_national_total BOOL
);
