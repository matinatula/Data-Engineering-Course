"""
transactional_loader.py
-----------------------
Week 3 Assignment — Q5
"""

# The output generated has been pasted at the bottom.

import psycopg2
import logging
import os
from dotenv import load_dotenv

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s  %(levelname)s  %(message)s"
)
logger = logging.getLogger(__name__)

load_dotenv()

DB_CONFIG = dict(
    host=os.getenv("DB_HOST"),
    port=os.getenv("DB_PORT"),
    dbname=os.getenv("DB_NAME"),
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
)

INSERT_SQL = """
    INSERT INTO trips (
        driver_id, passenger_id,
        pickup_location_id, dropoff_location_id,
        fare_amount, distance_km, status,
        requested_at, completed_at, rating, payment_method_id
    ) VALUES (
        %(driver_id)s, %(passenger_id)s,
        %(pickup_location_id)s, %(dropoff_location_id)s,
        %(fare_amount)s, %(distance_km)s, %(status)s,
        %(requested_at)s, %(completed_at)s,
        %(rating)s, %(payment_method_id)s
    )
"""


def load_batch(conn, rows: list) -> int:
    """
    Load a batch of trip rows inside a single transaction.

    Args:
        conn:  An open psycopg2 connection
        rows:  A list of dicts — each dict is one trip row

    Returns:
        Number of rows loaded (0 if the batch failed and rolled back)

    Raises:
        Exception: re-raised after rollback so the caller knows it failed
    """

    if not rows:
        return 0
    conn.autocommit = False
    with conn.cursor() as cur:
        try:
            for index, row in enumerate(rows, start=1):
                logger.info(f"Currently working on row: {index}")
                cur.execute(INSERT_SQL, row)
            conn.commit()
            return len(rows)
        except Exception as e:
            logger.error(f"Error occurred: {e}. Row: {index} failed.")
            conn.rollback()
            raise


def get_test_batches():
    """
    Returns two test batches:
      - good_batch: 5 valid trips (should commit)
      - bad_batch:  5 trips where row 3 has an invalid rating (should roll back)
    """
    base = dict(
        driver_id=1,
        passenger_id=1,
        pickup_location_id=1,
        dropoff_location_id=2,
        fare_amount=250.00,
        distance_km=8.5,
        status="completed",
        requested_at="2025-01-15 09:00:00",
        completed_at="2025-01-15 09:35:00",
        rating=4.5,
        payment_method_id=3,
    )

    good_batch = [{**base, "fare_amount": 100 * (i + 1)} for i in range(5)]

    bad_batch = []
    for i in range(5):
        row = {**base, "fare_amount": 100 * (i + 1)}
        if i == 2:
            row["rating"] = 99  # violates CHECK (rating BETWEEN 1.0 AND 5.0)
        bad_batch.append(row)

    return good_batch, bad_batch


def main():
    conn = psycopg2.connect(**DB_CONFIG)
    good_batch, bad_batch = get_test_batches()

    count_before = None
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM trips")
        count_before = cur.fetchone()[0]
    conn.commit()
    logger.info(f"Trips before any load: {count_before:,}")

    # ── Test 1: good batch ────────────────────────────────────────
    logger.info("--- Test 1: loading good batch (expect success) ---")
    try:
        loaded = load_batch(conn, good_batch)
        logger.info(f"Test 1 passed: {loaded} rows loaded")
    except Exception as e:
        logger.error(f"Test 1 failed unexpectedly: {e}")

    # ── Test 2: bad batch ─────────────────────────────────────────
    logger.info("--- Test 2: loading bad batch (expect rollback) ---")
    try:
        loaded = load_batch(conn, bad_batch)
        logger.warning(f"Test 2: loaded {loaded} rows — was rollback triggered?")
    except Exception:
        logger.info("Test 2 passed: exception raised after rollback")

    # ── Verify final count ────────────────────────────────────────
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM trips")
        count_after = cur.fetchone()[0]

    logger.info(f"Trips after both tests: {count_after:,}")
    logger.info(f"Net rows added: {count_after - count_before}")
    # Expected: +5 (good batch committed, bad batch rolled back)

    conn.close()


if __name__ == "__main__":
    main()


# Output generated:

# 2026-07-03 21:03:30,161  INFO  Trips before any load: 1,000,000
# 2026-07-03 21:03:30,161  INFO  --- Test 1: loading good batch (expect success) ---
# 2026-07-03 21:03:30,161  INFO  Currently working on row: 1
# 2026-07-03 21:03:30,165  INFO  Currently working on row: 2
# 2026-07-03 21:03:30,166  INFO  Currently working on row: 3
# 2026-07-03 21:03:30,166  INFO  Currently working on row: 4
# 2026-07-03 21:03:30,166  INFO  Currently working on row: 5
# 2026-07-03 21:03:30,168  INFO  Test 1 passed: 5 rows loaded
# 2026-07-03 21:03:30,168  INFO  --- Test 2: loading bad batch (expect rollback) ---
# 2026-07-03 21:03:30,168  INFO  Currently working on row: 1
# 2026-07-03 21:03:30,169  INFO  Currently working on row: 2
# 2026-07-03 21:03:30,169  INFO  Currently working on row: 3
# 2026-07-03 21:03:30,170  ERROR  Error occurred: numeric field overflow
# DETAIL:  A field with precision 2, scale 1 must round to an absolute value less than 10^1.
# . Row: 3 failed.
# 2026-07-03 21:03:30,170  INFO  Test 2 passed: exception raised after rollback
# 2026-07-03 21:03:30,186  INFO  Trips after both tests: 1,000,005
# 2026-07-03 21:03:30,186  INFO  Net rows added: 5