-- week3_reliability.sql
-- Week 3 Assignment

-- ─────────────────────────────────────────────────────────────────
-- Q1: Add indexes to the trips table
--
-- Before adding ANY index, run EXPLAIN ANALYZE on each query below
-- and record the execution time in a comment.
-- Then add your indexes and run EXPLAIN ANALYZE again.
-- The comparison IS the answer — not just the CREATE INDEX statement.
-- ─────────────────────────────────────────────────────────────────

-- STEP 1: DROP ANY existing indexes (clean baseline) ───────────

DROP INDEX IF EXISTS idx_trips_driver_id;

DROP INDEX IF EXISTS idx_trips_status;

DROP INDEX IF EXISTS idx_trips_driver_status;


-- STEP 2: Run WITHOUT indexes — record execution times ─────────

-- Query A: filter by driver_id
EXPLAIN ANALYZE
SELECT
	*
FROM
	trips
WHERE
	driver_id = 3;


-- Parallel Seq Scan on trips  (cost=0.00..18146.33 rows=13528 width=67) (actual time=0.227..72.224 rows=10406 loops=3)
-- Execution Time: 80.424 ms


-- Query B: filter by status
EXPLAIN ANALYZE
SELECT
	*
FROM
	trips
WHERE
	status = 'cancelled';

-- Seq Scan on trips  (cost=0.00..25438.00 rows=203633 width=67) (actual time=0.957..206.058 rows=200166 loops=1)
-- Execution Time: 212.089 ms


-- Query C: filter by driver_id AND status
EXPLAIN ANALYZE
SELECT
	*
FROM
	trips
WHERE
	driver_id = 3
	AND status = 'completed';


-- Parallel Seq Scan on trips  (cost=0.00..19188.00 rows=8112 width=67) (actual time=0.094..38.865 rows=6240 loops=3)
-- Execution Time: 47.993 ms

-- STEP 3: ADD indexes one AT a time ────────────────────────────

CREATE INDEX idx_trips_driver_id ON
trips(driver_id);



-- Re-run Query A immediately:
EXPLAIN ANALYZE
SELECT
	*
FROM
	trips
WHERE
	driver_id = 3;


-- Bitmap Heap Scan on trips  (cost=364.04..13707.88 rows=32467 width=67) (actual time=6.409..24.189 rows=31218 loops=1)
-- Execution Time: 26.026 ms (before creating index, the time was 80.424 ms)

-- Query A before: Parallel Seq Scan, execution time = 80.424 ms
-- Query A after:  Bitmap Heap Scan, execution time = 26.026 ms



CREATE INDEX idx_trips_status ON
trips(status);



-- Re-run Query B:
EXPLAIN ANALYZE
SELECT
	*
FROM
	trips
WHERE
	status = 'cancelled';

-- Bitmap Heap Scan on trips  (cost=2282.58..17765.99 rows=203633 width=67) (actual time=22.365..113.122 rows=200166 loops=1)
-- Bitmap Index Scan on idx_trips_status  (cost=0.00..2231.67 rows=203633 width=0) (actual time=19.859..19.860 rows=200166 loops=1)
-- Execution Time: 120.933 ms (before creating the index, the time was  212.089 ms)

-- Query B before: Seq Scan, execution time = 212.089 ms
-- Query B after:  Bitmap Heap Scan on trips, Bitmap Index Scan on idx_trips_status, execution time = 120.933ms


CREATE INDEX idx_trips_driver_status ON
trips(driver_id, status);



-- Re-run Query C:
EXPLAIN ANALYZE
SELECT
	*
FROM
	trips
WHERE
	driver_id = 3
	AND status = 'completed';

-- Bitmap Heap Scan on trips  (cost=360.80..13785.80 rows=19470 width=67) (actual time=5.917..26.453 rows=18719 loops=1)
-- Bitmap Index Scan on idx_trips_driver_id  (cost=0.00..355.93 rows=32467 width=0) (actual time=3.673..3.673 rows=31218 loops=1)
-- Execution Time: 27.509 ms (before creating the index, the time was 47.993 ms)

-- Query C before: Parallel Seq Scan, execution time = 47.993 ms
-- Query C after:  Bitmap Heap Scan on trips, Bitmap Index Scan on idx_trips_driver_id , execution time = 27.509 ms



-- STEP 4: The covering INDEX bonus (advanced) ──────────────────

CREATE INDEX idx_trips_driver_fare
ON
trips(driver_id)
INCLUDE (fare_amount);

EXPLAIN ANALYZE
SELECT
	driver_id,
	SUM(fare_amount)
FROM
	trips
WHERE
	driver_id = 3
GROUP BY
	driver_id;

-- GroupAggregate  (cost=0.42..1409.65 rows=1 width=36) (actual time=14.987..14.988 rows=1 loops=1)
-- Index Only Scan using idx_trips_driver_fare on trips  (cost=0.42..1328.47 rows=32467 width=10) (actual time=0.111..10.911 rows=31218 loops=1)
-- Execution Time: 15.095 ms

-- ─────────────────────────────────────────────────────────────────
-- Q2: Create completed_trips_view
--
-- Must return only completed trips with ALL of these columns:
--   trip_id, driver_name, rider_name,
--   pickup_city, dropoff_city,
--   fare_amount, distance_km, rating,
--   payment_method, requested_at, completed_at
--
-- No IDs in the output — use JOINs to resolve all foreign keys.

CREATE VIEW completed_trips_view AS
SELECT
	t.trip_id ,	
	d.name AS driver_name,
	p.name AS passenger_name,
	pck.city_name AS pickup_location_city,
	drp.city_name AS dropoff_location_city,
	t.fare_amount ,
	t.distance_km ,
	t.rating,
	pm.name AS payment_method,
	t.requested_at,
	t.completed_at
FROM
	trips t
INNER JOIN drivers d ON
	t.driver_id = d.driver_id
INNER JOIN passengers p ON
	t.passenger_id = p.passenger_id
INNER JOIN locations pck ON
	t.pickup_location_id = pck.location_id
INNER JOIN locations drp ON
	t.dropoff_location_id = drp.location_id
INNER JOIN payment_methods pm ON
	t.payment_method_id = pm.payment_method_id
WHERE t.status = 'completed';

-- ─────────────────────────────────────────────────────────────────
-- Q3: Create driver_summary view
--
-- Must show one row per driver with:
--   driver_name
--   total_trips          (all statuses)
--   completed_trips
--   cancelled_trips
--   cancellation_rate    (cancelled / total * 100, rounded to 1dp)
--   avg_fare             (completed trips only, rounded to 2dp)
--   avg_rating           (completed trips only, rounded to 1dp)
--
-- Challenge: use COUNT(*) FILTER (WHERE ...) instead of CASE WHEN
-- ─────────────────────────────────────────────────────────────────


CREATE VIEW driver_summary AS
SELECT
	d.name AS driver_name,
	COUNT(t.trip_id) AS total_trips,
	COUNT(t.trip_id) FILTER (WHERE t.status = 'completed') completed_trips,
	COUNT(t.trip_id) FILTER (WHERE t.status = 'cancelled') cancelled_trips,
	ROUND((COUNT(t.trip_id) FILTER (WHERE t.status = 'cancelled') * 100.0 / NULLIF(COUNT(t.trip_id), 0)), 1) AS cancellation_rate,
	ROUND(AVG(t.fare_amount) FILTER (WHERE t.status='completed'), 2) AS average_fare,
	ROUND(AVG(t.rating) FILTER (WHERE t.status='completed'), 1) AS average_rating
FROM
	drivers d
LEFT JOIN trips t ON
	t.driver_id = d.driver_id
GROUP BY
	d.driver_id, d.name;

-- ─────────────────────────────────────────────────────────────────
-- Q4: Transaction with intentional failure
--
-- Write a transaction that:
--   1. Inserts a new driver named 'Test Driver'
--   2. Inserts 3 valid trips for that driver
--   3. Inserts a 4th trip with rating = 99 (violates CHECK constraint)
--
-- The entire transaction should roll back.
-- Verify with: SELECT * FROM drivers WHERE name = 'Test Driver';
-- Expected: 0 rows (atomicity — nothing committed)
-- ─────────────────────────────────────────────────────────────────

BEGIN;

-- Insert the driver and get the generated driver_id
WITH new_driver AS (
    INSERT INTO drivers (name)
    VALUES ('Test Driver')
    RETURNING driver_id
)

-- Insert 3 valid trips
INSERT INTO trips (
    driver_id,
    passenger_id,
    pickup_location_id,
    dropoff_location_id,
    fare_amount,
    distance_km,
    status,
    requested_at,
    completed_at,
    rating,
    payment_method_id
)
SELECT
    driver_id,
    1, 1, 2,
    250, 8.5,
    'completed',
    NOW(), NOW(),
    5,
    1
FROM new_driver

UNION ALL

SELECT
    driver_id,
    2, 2, 3,
    300, 10.2,
    'completed',
    NOW(), NOW(),
    4,
    2
FROM new_driver

UNION ALL

SELECT
    driver_id,
    3, 3, 4,
    180, 5.6,
    'completed',
    NOW(), NOW(),
    5,
    1
FROM new_driver;

-- 4th trip (this should fail)
INSERT INTO trips (
    driver_id,
    passenger_id,
    pickup_location_id,
    dropoff_location_id,
    fare_amount,
    distance_km,
    status,
    requested_at,
    completed_at,
    rating,
    payment_method_id
)
SELECT
    driver_id,
    4, 4, 5,
    220, 7.8,
    'completed',
    NOW(), NOW(),
    99,
    1
FROM drivers
WHERE name = 'Test Driver';

COMMIT;

-- Verification query:
SELECT
    'drivers' AS tbl,
    COUNT(*) AS test_driver_rows
FROM drivers
WHERE name = 'Test Driver'
UNION ALL
SELECT 'trips', COUNT(*)
FROM trips t
JOIN drivers d ON t.driver_id = d.driver_id
WHERE d.name = 'Test Driver';

-- Output:
-- drivers	0
-- trips	0

-- This insert intentionally fails (rating = 99).
-- PostgreSQL aborts the transaction, so nothing is committed.

-- ─────────────────────────────────────────────────────────────────
-- Q6 (STRETCH): Window function — running total fare per driver
--
-- For each completed trip, show:
--   trip_id, driver_name, requested_at, fare_amount,
--   running_total_fare (driver's cumulative fare up to this trip)
--
-- Use: SUM(fare_amount) OVER (PARTITION BY driver_id ORDER BY requested_at)
-- Order the final output by driver_name, requested_at
-- ─────────────────────────────────────────────────────────────────

SELECT
	t.trip_id,
	d.name AS driver_name,
	t.requested_at,
	t.fare_amount,
	SUM(t.fare_amount) OVER (
        PARTITION BY t.driver_id
ORDER BY
	t.requested_at
    ) AS running_total_fare
FROM
	trips t
JOIN drivers d
    ON
	t.driver_id = d.driver_id
WHERE
	t.status = 'completed'
ORDER BY
	d.name,
	t.requested_at;