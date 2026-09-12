# Executive Summary — Australian Domestic Airline Reliability & Market Recovery

*Full SQL: [`sql/00_staging_schema.sql`](sql/00_staging_schema.sql) – [`sql/03_business_analysis.sql`](sql/03_business_analysis.sql). Query execution & charts: [`australian_airline_market_analysis.ipynb`](australian_airline_market_analysis.ipynb).*

## Business Problem

Australian domestic aviation has been through a total COVID shutdown, a chaotic 2022 reopening, and the 2024 collapse of budget carrier Bonza — yet the popular narrative is a simple "recovered from COVID" story. This analysis tests that narrative against 22 years of real BITRE flight data: **which airlines are actually the most reliable today, which routes never recovered their pre-COVID capacity, and does losing a competing airline measurably concentrate a market?**

## Data

**Source:** [BITRE (Bureau of Infrastructure and Transport Research Economics)](https://www.data.gov.au) — "Domestic airline on time performance time series," monthly, route × airline grain, January 2004 – July 2026.

| Table | Rows | Content |
|---|---|---|
| `staging_otp` | 119,038 | Raw CSV, all columns loaded as STRING, 1:1 with source |
| `flights_monthly` | 119,038 | Typed/cleaned: route, ports, airline, month, sectors scheduled/flown, cancellations, on-time/delayed departures & arrivals, plus two rollup flags |

**Data-quality decisions made before analysis (not assumed):**
- BITRE includes its own **"All Airlines" rollup row** per route/month. Verified directly (Adelaide–Brisbane, Jun-2019: Jetstar 22 + Qantas 103 + QantasLink 1 + Tigerair 30 + Virgin 102 = 258 sectors flown = the "All Airlines" row for that route/month exactly) — a true sum, not a separate estimate. Flagged as `is_all_airlines` so per-airline queries can exclude it and route-total queries can use it directly instead of re-summing.
- BITRE also includes an **"All Ports-All Ports" nationwide rollup row** (appears under every individual airline too, not just "All Airlines") — flagged as `is_national_total` and excluded from all route-level analysis.
- 20 raw airline-name spellings collapsed data-entry inconsistencies for the same carrier: `Macair`/`MacAir` and `virgin Australia`/`Virgin Australia` were standardised in the ETL. Genuine rebrands (`Skytrans` → `Skytrans Australia`) were left as distinct entities since that reflects a real business change, not a typo.
- `Cancellations` (316 blank rows) and `Departures_Delayed` (5 blank rows) are loaded as `NULL` via `SAFE_CAST` rather than failing the load or being coerced to zero.
- 2026 is a partial year (7 of 12 months at analysis time) and is excluded from every year-over-year comparison.

## Methodology

1. **Cloud ETL** (`sql/00`–`02`): raw CSV loaded into an all-STRING staging table in Google BigQuery, then cast/cleaned into a typed `flights_monthly` table with the two rollup flags described above.
2. **8 business questions answered entirely in SQL** (`sql/03`), using CTEs, `RANK()`, `LAG()`, and analytic window functions with `QUALIFY` for ranking, year-over-year comparison, and market-concentration (HHI) calculations.
3. **Every query executed and its output inspected** before being written up — no number below is asserted without having been produced by a query run against the live BigQuery tables.

## Results

**1. National capacity trend (2004–2026).** Monthly domestic sectors flown grew steadily from ~31,700/month (2004) to a peak of ~47,500/month (2018–19), collapsed to a low of **13,300/month at the depth of COVID (mid-2021)**, and by 2025 has recovered to ~44,700/month — **still ~6% below the pre-COVID peak**, five years on.

**2. National on-time arrival rate (2015–2025).** Fell for four consecutive pre-COVID years (86.1% in 2015 → 77.5% in 2019), then — counterintuitively — *improved* during COVID lockdowns as lighter traffic meant less congestion (86.1% in 2021), before **crashing to 67.4% in 2022** (an 18.7-percentage-point single-year drop) as travel demand reopened faster than airlines could staff and schedule for it. Recovery since has been gradual: 69.4% (2023) → 73.3% (2024) → 75.8% (2025) — still below the 2019 pre-COVID rate.

**3. Airline reliability ranking (2025).** Among carriers with 1,000+ sectors flown: **Qantas leads at 77.3%** arrivals on time, narrowly ahead of **Virgin Australia and QantasLink (both 76.0%)**, then Rex Airlines and Jetstar (both 74.3%), with **Virgin Australia Regional Airlines trailing at 68.9%**.

**4. Worst post-COVID route recovery.** Comparing 2019 (pre-COVID baseline) to 2025 average monthly flights, restricted to routes with 20+ flights/month in 2019: **Albury–Sydney sits at just 63% of its 2019 capacity** (249 → 157 flights/month), followed by Sydney–Wagga Wagga (80%), Port Lincoln–Adelaide (77%), Gladstone–Brisbane (75%), and Canberra–Melbourne (74%) — all still materially under-served relative to before the pandemic.

**5. Routes that grew beyond 2019 capacity.** The flip side of Q4: **Adelaide–Canberra now flies at 146% of its 2019 capacity** (73 → 107 flights/month), Brisbane–Hobart at 134%, Launceston–Sydney at 130%, and Sunshine Coast–Melbourne at 129% — a genuine domestic leisure-travel boom on holiday routes, not merely a return to baseline.

**6. Vanished routes.** A stricter test than reduced capacity: **18 routes that had scheduled commercial air service in 2019 have none at all in 2025**, including Sydney–Darwin, Sydney–Townsville, Sydney–Ayers Rock, Sydney–Tamworth, Sydney–Proserpine, Sydney–Armidale, and Perth–Geraldton — regional and secondary-city connectivity that simply hasn't returned.

**7. Market concentration (2025).** Among routes with 500+ sectors/year, computing each route's HHI (Herfindahl-Hirschman Index — the sum of every competing airline's squared market share; US antitrust regulators treat >2,500 as "highly concentrated"): the 15 most concentrated routes **all have HHI above 5,200 and are all two-carrier duopolies** — e.g. Cairns–Townsville (HHI 8,358, top carrier 91% share), Adelaide–Canberra (HHI 7,317, 84% share). Critically, **zero routes at this volume threshold are true single-carrier monopolies** — every route retains at least some competitive pressure, even if concentrated in a duopoly.

**8. Case study: Bonza's 2024 collapse.** Bonza flew only 6 routes before entering administration in April 2024. Comparing 2023 (Bonza flying) to 2025 (Bonza gone) on those same 6 routes: **market concentration (HHI) rose on every single one** — e.g. Melbourne↔Mildura rose from HHI 4,967/53.6% top share (3 carriers) to HHI 5,073/56.0% (2 carriers); Gold Coast↔Melbourne rose from HHI ~3,916 (6 carriers active across the year) to ~4,211 (3 carriers) — while **total sectors flown on these routes barely changed**, meaning fewer competitors are now carrying essentially the same traffic, not that demand collapsed alongside Bonza.

## Interpretation

The popular framing — "Australian aviation recovered from COVID" — is only half true. **National capacity still sits below its pre-pandemic peak, and reliability took far longer to recover than capacity did** (it initially *improved* during lockdowns, then collapsed further once demand returned in 2022, pointing squarely to a staffing/operational-readiness failure rather than a demand problem). The recovery that did happen was **deeply uneven geographically**: regional Australia lost service on routes that may never return, while domestic leisure corridors are now flying above pre-COVID levels — a genuine post-pandemic shift in travel patterns, not uniform "recovery." Layered on top, the Bonza case study shows Australia's route-level aviation competition has very little slack: losing one low-cost entrant on just 6 routes was enough to measurably concentrate every one of them, with no evidence another carrier absorbed the gap in reduced competition.

## Business Recommendations

1. **Regional connectivity loss deserves policy attention as a permanent structural change, not a lingering COVID after-effect still working itself out** — the 18 vanished routes and routes like Albury–Sydney (63% of 2019 capacity) show no sign of returning on current trend.
2. **The 2022 reliability crisis is an operations/staffing story, and should inform workforce-planning policy for future demand shocks** — capacity had already substantially recovered by 2022 when on-time performance cratered, meaning the constraint was people and scheduling, not aircraft or route networks.
3. **Route-level competition is fragile and worth monitoring** — with zero true monopolies but pervasive duopoly-level concentration, further low-cost-carrier consolidation (following Bonza and Tigerair's earlier 2020 exit) would likely concentrate more routes further, with limited natural entry to counteract it.

## Limitations

- BITRE's own on-time definitions and thresholds are used as-is; not independently re-derived.
- `is_all_airlines` / `is_national_total` rollups are trusted as verified sums of the underlying rows (spot-checked, not exhaustively re-derived for all 119,038 rows) — a systematic BITRE reporting error in those specific columns would carry through undetected.
- 2026 (partial year, 7 months) is excluded from all year-over-year and baseline comparisons.
- HHI is computed on **sectors flown** as a capacity proxy, not passenger volume, seats, or revenue — a consistent basis across carriers, but not identical to how a regulator like the ACCC would formally define a route's relevant market.
- Single BITRE data vintage (dataset as published as of the analysis date) — no comparison against a prior release to check for retrospective revisions.
