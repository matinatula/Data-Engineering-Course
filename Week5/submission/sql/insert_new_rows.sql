INSERT
	INTO
	trips (driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	vehicle_id,
	payment_method_id,
	promo_code_id,
	base_fare,
	tip_amount,
	discount_amount,
	surge_multiplier,
	distance_km,
	status,
	requested_at,
	completed_at,
	driver_rating,
	passenger_rating)
SELECT
	driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	vehicle_id,
	payment_method_id,
	promo_code_id,
	base_fare,
	tip_amount,
	discount_amount,
	surge_multiplier,
	distance_km,
	status,
	NOW() + (n || ' seconds')::INTERVAL,
	NOW() + (n || ' seconds')::INTERVAL + INTERVAL '20 minutes',
	driver_rating,
	passenger_rating
FROM
	trips,
	generate_series(1, 5) AS n
LIMIT 5;