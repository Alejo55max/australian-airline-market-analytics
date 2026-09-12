-- Staging table: every column loaded as STRING, straight from the raw BITRE
-- CSV header (Route, Departing_Port, Arriving_Port, Airline, Month,
-- Sectors_Scheduled, Sectors_Flown, Cancellations, Departures_On_Time,
-- Arrivals_On_Time, Departures_Delayed, Arrivals_Delayed, Year, Month_Num).
-- No casting/cleaning happens here — that's 02_transform_load.sql.

CREATE SCHEMA IF NOT EXISTS `airline_ontime`;

CREATE OR REPLACE TABLE `airline_ontime.staging_otp` (
    Route STRING,
    Departing_Port STRING,
    Arriving_Port STRING,
    Airline STRING,
    Month STRING,
    Sectors_Scheduled STRING,
    Sectors_Flown STRING,
    Cancellations STRING,
    Departures_On_Time STRING,
    Arrivals_On_Time STRING,
    Departures_Delayed STRING,
    Arrivals_Delayed STRING,
    Year STRING,
    Month_Num STRING
);
