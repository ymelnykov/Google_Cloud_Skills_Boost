-- My solution to Create ML Models with BigQuery ML Challenge Lab

-- Task 2. Create a forecasting BigQuery machine learning model
CREATE or REPLACE MODEL 
  bike_trips.bike_trip_duration_model
OPTIONS
  (model_type='linear_reg', labels=['duration_minutes']) AS
SELECT
  duration_minutes,
  start_station_name,
  EXTRACT(HOUR FROM start_time) AS hour_of_day,
  EXTRACT(DAYOFWEEK FROM start_time) AS day_of_week,
  address as location
FROM
  `bigquery-public-data.austin_bikeshare.bikeshare_trips` AS trips
JOIN
  `bigquery-public-data.austin_bikeshare.bikeshare_stations` AS stations
ON
  trips.start_station_name = stations.name
WHERE
  EXTRACT(YEAR FROM start_time) = 2016
  

-- Task 3. Create the second machine learning model
CREATE or REPLACE MODEL 
  bike_trips.bike_trip_duration_model_2
OPTIONS
  (model_type='linear_reg', labels=['duration_minutes']) AS
SELECT
  duration_minutes,
  start_station_name AS station,
  subscriber_type,
  start_time
FROM
  `bigquery-public-data.austin_bikeshare.bikeshare_trips`
WHERE
  EXTRACT(YEAR FROM start_time) = 2016
	 
	 
-- Task 4. Evaluate the two machine learning models	  
-- Query 1
SELECT
  SQRT(mean_squared_error) AS rmse,
  mean_absolute_error
FROM
  ML.EVALUATE(MODEL bike_trips.bike_trip_duration_model,
  (
  SELECT
    duration_minutes,
    start_station_name,
    EXTRACT(HOUR FROM start_time) AS hour_of_day,
    EXTRACT(DAYOFWEEK FROM start_time) AS day_of_week,
    address as location
  FROM
    `bigquery-public-data.austin_bikeshare.bikeshare_trips` AS trips
  JOIN
    `bigquery-public-data.austin_bikeshare.bikeshare_stations` AS stations
  ON
    trips.start_station_name = stations.name
  WHERE
    EXTRACT(YEAR FROM start_time) = 2019
  ))

-- Query 2
SELECT
  SQRT(mean_squared_error) AS rmse,
  mean_absolute_error
FROM
  ML.EVALUATE(MODEL bike_trips.bike_trip_duration_model_2,
  (
  SELECT
    duration_minutes,
    start_station_name AS station,
    subscriber_type,
    start_time
  FROM
    `bigquery-public-data.austin_bikeshare.bikeshare_trips`
  WHERE
    EXTRACT(YEAR FROM start_time) = 2019
  ))
  

-- Task 5. Use the subscriber type machine learning model to predict average trip durations
 WITH busiest_station AS 
  (
  SELECT
    start_station_name AS station_name,
    COUNT(*) AS num_trips
  FROM 
    `bigquery-public-data.austin_bikeshare.bikeshare_trips`
  WHERE
    EXTRACT(YEAR FROM start_time) = 2019
  GROUP BY start_station_name
  ORDER BY num_trips DESC
  LIMIT 1
  )

SELECT 
  AVG(predicted_duration_minutes) AS average_predicted_duration_minutes
FROM 
  ML.PREDICT(MODEL bike_trips.bike_trip_duration_model_2,
  (
  SELECT
    duration_minutes,
    start_station_name AS station,
    subscriber_type,
    start_time
  FROM
    `bigquery-public-data.austin_bikeshare.bikeshare_trips`,
    busiest_station
  WHERE
    EXTRACT(YEAR FROM start_time) = 2019 AND
    subscriber_type = 'Single Trip' AND
    start_station_name = station_name 
  ))