# Week 4 Assignment — Ride-Sharing Warehouse

Complete the tasks below directly in `warehouse.sql` and `etl.py`. Add any
analysis queries and your written answers to this file under the matching
section.

## 1. `warehouse.sql` — add the vehicle dimension

- Create a `dim_vehicle` table (surrogate key `vehicle_key`, natural key
  `vehicle_id`, plus the descriptive vehicle attributes from the OLTP
  `vehicles` table: plate number, make, model, year, color, category,
  is_active).
- Add `vehicle_key` and `time_key` columns to `fact_trips`, referencing
  `dim_vehicle(vehicle_key)` and `dim_time(time_key)` respectively.
  - Think about whether each new key should be `NOT NULL` — is `vehicle_id`
    always present on a trip in the OLTP schema? Is a time always known?

```text
Completed directly in `warehouse.sql`.

Written reasoning for the NOT NULL decisions is included there as SQL comments below the ALTER TABLE fact_trips statement.
```


## 2. `etl.py` — implement the remaining dimension + fact columns

- Add `extract_vehicle` / `load_dim_vehicle` following the pattern of the
  existing dimension loaders.
- Add `vehicle` and `time` to `load_lookup_dim`.
- In `transform`, resolve `vehicle_key` and `time_key` for each trip
  (remember `dim_time.time_key` is the requested time rounded **down** to
  the nearest 15-minute bucket, e.g. 14:37 → `1430`).
- Wire the new columns through `load_fact_trips`.

```text
Completed directly in `etl.py`.

Comments explaining the YEAR/year casing fix and the ON CONFLICT DO NOTHING behavior are included inline near the relevant functions.
```

## 3. Revenue by city / month

Write a warehouse query that returns total revenue grouped by pickup city
and month.

Then write the equivalent query against the OLTP schema (`trips`,
`locations`, etc.) directly.

**Answer:** how many table joins does each version need? Which one needed
fewer, and why?

**Warehouse query:**
```sql
SELECT
	ROUND(SUM(ft.fare_amount),2) AS total_revenue,
	dl.city_name,
	dd.month_name,
	dd.year
FROM
	fact_trips ft
JOIN dim_location dl ON
	ft.pickup_location_key = dl.location_key
JOIN dim_date dd ON
	ft.date_key = dd.date_key
GROUP BY
	dl.city_name,
	dd.month_name,
	dd.MONTH,
	dd.year
ORDER BY
	dd.year,
	dd.month,
	dl.city_name;
```

**OLTP-direct query:**
```sql
SELECT
	l.city_name ,
	TRIM(TO_CHAR(t.requested_at, 'Month')) AS month_name,
	EXTRACT(YEAR FROM t.requested_at) AS YEAR,
	ROUND((SUM(t.base_fare * t.surge_multiplier + t.tip_amount - t.discount_amount)), 2) AS total_revenue
FROM
	trips t
JOIN locations l ON
	t.pickup_location_id = l.location_id
GROUP BY
	l.city_name,
	TRIM(TO_CHAR(t.requested_at, 'Month')),
	YEAR,
	EXTRACT(MONTH FROM t.requested_at)
ORDER BY
	l.city_name,
	EXTRACT(MONTH FROM t.requested_at) ,
	YEAR;
```

**Answer:**

Warehouse needs 2 joins (dim_location, dim_date), OLTP only needs 1 (locations). So actually OLTP needed fewer joins here, since month and year can be pulled directly from requested_at using EXTRACT/TO_CHAR, no separate table needed for that.

But the extra join in warehouse isn't useless — dim_date already has stuff like is_weekend and week_of_year precomputed and stored. Same for dim_time (not used in this query but same idea) which has is_rush_hour. So if someone later asks something like "revenue on weekends only" or "revenue during rush hour", warehouse can just filter on that column directly, but OLTP would have to write that date/time logic from scratch every single time in every query. So the extra join is basically a tradeoff; a bit more joining now, in exchange for way simpler queries later.

## 4. Payment method revenue

- Write a warehouse query for total revenue per payment method.
- Extend it (or write a second query) for **average fare per trip, per
  payment method, per month**.

**Query (covers both total revenue and average fare per trip, per payment method, per month):**
```sql
-- Combined both parts of Task 4 into one query: total revenue and
-- average fare per trip are both grouped by payment method + month + year.
-- AVG(fare_amount) here is "average fare per trip" since each row in
-- fact_trips already represents exactly one trip.

SELECT
	dpm.name AS payment_method_name,
	dd.month_name,
	dd.YEAR,
	ROUND(SUM(ft.fare_amount), 2) AS total_revenue_per_payment_method,
	ROUND(AVG(ft.fare_amount), 2) AS average_fare_per_payment_method
FROM
	fact_trips ft
JOIN dim_payment_method dpm 
ON
	ft.payment_method_key = dpm.payment_method_key
JOIN dim_date dd 
ON
	ft.date_key = dd.date_key
GROUP BY
	dpm.name,
	dd.MONTH,
	dd.month_name,
	dd.year
ORDER BY
	dd.month ,
	dd.YEAR,
	total_revenue_per_payment_method DESC;
```

## 5. Busiest hour of day

Write a warehouse query that returns trip count per hour of day (0–23),
along with each hour's percentage of all trips — computed with a **window
function** (not a second query for the grand total).

## 5. Busiest hour of day

**Query:**
```sql
SELECT
	dt.hour,
	COUNT(*) AS trip_count,
	ROUND((COUNT(*) * 100.0 / (SUM(COUNT(*)) OVER ())), 2) AS pct_of_all_trips
FROM
	dim_time dt
JOIN fact_trips ft
ON
	dt.time_key = ft.time_key
GROUP BY
	dt.hour
ORDER BY
	dt.hour;
```

**Answer:**

| Hour | Trip Count | % of All Trips |
|------|-----------|-----------------|
| 0 | 400 | 4.00 |
| 1 | 414 | 4.14 |
| 2 | 435 | 4.35 |
| 3 | 446 | 4.46 |
| 4 | 424 | 4.24 |
| 5 | 417 | 4.17 |
| 6 | 413 | 4.13 |
| 7 | 430 | 4.30 |
| 8 | 397 | 3.97 |
| 9 | 409 | 4.09 |
| 10 | 419 | 4.19 |
| 11 | 395 | 3.95 |
| 12 | 445 | 4.45 |
| 13 | 436 | 4.36 |
| 14 | 413 | 4.13 |
| 15 | 409 | 4.09 |
| 16 | 420 | 4.20 |
| 17 | 420 | 4.20 |
| 18 | 369 | 3.69 |
| 19 | 402 | 4.02 |
| 20 | 437 | 4.37 |
| 21 | 392 | 3.92 |
| 22 | 437 | 4.37 |
| 23 | 421 | 4.21 |

Trip volume is fairly evenly distributed across all 24 hours where each hour sits close to the expected 1/24 ≈ 4.17% if trips were perfectly uniform. The busiest hour is **hour 3 (3-4 AM)**, with 446 trips (4.46% of all trips). The quietest is **hour 18 (6-7 PM)**, with 369 trips (3.69%). Total trip count (400+414+...+421) sums to exactly 10,000, and percentages sum to exactly 100.00%, confirming the window function correctly computed the grand total across the full result set.

## 7. Stretch: incremental load (watermark pattern)

Modify `etl.py` so the fact load only extracts trips newer than the
`MAX(requested_at)` already present in `fact_trips`. Where should that
watermark be read from, and what happens the very first time the ETL runs
against an empty warehouse?

> **Changes to `etl.py`:**
>
> * Added `get_watermark(conn)` where queries `SELECT MAX(requested_at) FROM fact_trips` on the destination (warehouse) connection.
> * Modified `extract_trips(conn, watermark=None)` to accept an optional watermark and add `WHERE t.requested_at > %s` when one is provided.
> * `main()` now calls `get_watermark(dst_conn)` before extracting trips and passes it into `extract_trips`.
>
> **Answer:**
>
> The watermark is read from `fact_trips.requested_at` in the destination warehouse. `MAX(requested_at)` gives the most recent trip already loaded.
>
> On the first ETL run against an empty warehouse, `MAX(requested_at)` returns `NULL`, so the watermark is `None`, and the query skips the `WHERE` filter entirely and extracts all trips. Otherwise, `t.requested_at > NULL` would evaluate to unknown for every row and silently load nothing.
>
> **Verified:**
>
> Ran the ETL a second time against an already-populated warehouse. The watermark was correctly picked up as `2026-06-29 21:53:01`, extracted `0` new trips (all already loaded), transformed `0`, and skipped the load cleanly with no errors.

