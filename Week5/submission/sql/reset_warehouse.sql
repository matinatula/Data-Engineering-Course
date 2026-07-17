TRUNCATE
	TABLE dim_driver,
	dim_passenger,
	dim_location,
	dim_payment_method,
	dim_promo_code,
	dim_vehicle,
	fact_trips
RESTART IDENTITY CASCADE;