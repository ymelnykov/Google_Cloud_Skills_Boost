-- My solution to Engineer Data in Google Cloud Challenge Lab

-- Task 2. Create a BigQuery ML model
CREATE OR REPLACE MODEL 
  `taxirides.fare_model_936`
TRANSFORM
(
  pickup_datetime,
  passenger_count,
  ST_Distance(ST_GeogPoint(pickup_longitude, pickup_latitude), ST_GeogPoint(dropoff_longitude, dropoff_latitude)) AS euclidean,
  fare_amount_818
)
OPTIONS
(
  model_type='linear_reg',
  input_label_cols= ['fare_amount_818']
)
AS
SELECT
  * 
FROM
  `taxirides.taxi_training_data_107`
WHERE 
  pickup_latitude BETWEEN -90 AND 90
  AND dropoff_latitude BETWEEN -90 AND 90


-- Task 3. Perform a batch prediction on new data
CREATE TABLE 
  taxirides.2015_fare_amount_predictions
AS 
(
SELECT
  *
FROM
  ML.PREDICT(MODEL `taxirides.fare_model_936`,
    (
    SELECT
      CAST(pickup_datetime AS DATETIME) AS pickup_datetime,
      pickuplon AS pickup_longitude,
      pickuplat AS pickup_latitude,
      dropofflon AS dropoff_longitude,
      dropofflat AS dropoff_latitude,
      passengers AS passenger_count
    FROM
      `taxirides.report_prediction_data`
    )))