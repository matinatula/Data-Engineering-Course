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

── CLEANUP ────────────

DROP INDEX IF EXISTS idx_trips_driver_id;

DROP INDEX IF EXISTS idx_trips_status;

DROP INDEX IF EXISTS idx_trips_driver_status;

DROP INDEX IF EXISTS idx_trips_driver_fare;




