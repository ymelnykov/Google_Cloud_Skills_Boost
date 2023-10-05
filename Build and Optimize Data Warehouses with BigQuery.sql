-- My solution to Build and Optimize Data Warehouses with BigQuery Challenge Lab

-- Task 1. Create a table partitioned by date
CREATE OR REPLACE TABLE covid_299.oxford_policy_tracker_289
 PARTITION BY 
	date
 OPTIONS (
   partition_expiration_days=1080
 ) AS
 SELECT
   *
 FROM 
	`bigquery-public-data.covid19_govt_response.oxford_policy_tracker`
 WHERE 
	alpha_3_code NOT IN ('GBR', 'BRA', 'CAN', 'USA')


-- Task 3. Add country population data to the population column
UPDATE
    covid_299.oxford_policy_tracker_289 as t
SET
    t.population = s.pop_data_2019
FROM
    (SELECT DISTINCT country_territory_code, pop_data_2019 FROM `bigquery-public-data.covid19_ecdc.covid_19_geographic_distribution_worldwide`) AS s
WHERE t.alpha_3_code = s.country_territory_code;


-- Task 4. Add country area data to the country_area column
UPDATE 
	covid_299.oxford_policy_tracker_289 AS t
SET 
	t.country_area = s.country_area
FROM 
	bigquery-public-data.census_bureau_international.country_names_area AS s
WHERE 
	t.country_name = s.country_name;

 
-- Task 5. Populate the mobility record data
UPDATE covid_299.oxford_policy_tracker_289 AS t
SET
  t.mobility = STRUCT(
    s.avg_retail AS avg_retail,
    s.avg_grocery AS avg_grocery,
    s.avg_parks AS avg_parks,
	s.avg_transit AS avg_transit,
	s.avg_workplace AS avg_workplace,
	s.avg_residential AS avg_residential
  )
FROM (SELECT country_region, date,
      AVG(retail_and_recreation_percent_change_from_baseline) as avg_retail,
      AVG(grocery_and_pharmacy_percent_change_from_baseline)  as avg_grocery,
      AVG(parks_percent_change_from_baseline) as avg_parks,
      AVG(transit_stations_percent_change_from_baseline) as avg_transit,
      AVG( workplaces_percent_change_from_baseline ) as avg_workplace,
      AVG( residential_percent_change_from_baseline)  as avg_residential
      FROM `bigquery-public-data.covid19_google_mobility.mobility_report`
      GROUP BY country_region, date) AS s
WHERE t.common_key = s.country_region AND t.date = s.date;


-- Task 6. Query missing data in population & country_area columns
SELECT DISTINCT 
	country_name, population, country_area
FROM 
	covid_299.oxford_policy_tracker_289
WHERE 
	population IS NULL 
UNION ALL
SELECT DISTINCT 
	country_name, population, country_area
FROM 
	covid_299.oxford_policy_tracker_289
WHERE 
	country_area IS NULL 
ORDER BY 
	country_name