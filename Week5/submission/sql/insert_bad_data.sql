ALTER TABLE trips DROP CONSTRAINT chk_discount_not_exceed_base;

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
	9999,
	surge_multiplier,
	distance_km,
	'completed',
	NOW(),
	NOW(),
	driver_rating,
	passenger_rating
FROM
	trips
LIMIT 1;