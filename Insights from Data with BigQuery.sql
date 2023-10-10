-- My solution to Insights from Data with BigQuery Challenge Lab

-- Task 1. Total confirmed cases
SELECT
  SUM(cumulative_confirmed) AS total_cases_worldwide
FROM 
  `bigquery-public-data.covid19_open_data.covid19_open_data`
WHERE 
  date='2020-05-15'


-- Task 2. Worst affected areas
WITH states AS (
SELECT
  subregion1_name AS state, 
  SUM(cumulative_deceased) as total_fatality
FROM 
  `bigquery-public-data.covid19_open_data.covid19_open_data`
WHERE 
  date='2020-05-15'
  AND country_name='United States of America'
  AND subregion1_name IS NOT NULL
GROUP BY 
  subregion1_name)

SELECT
  COUNT(state) AS count_of_states
FROM 
  states
WHERE
  total_fatality > 200


-- Task 3. Identifying hotspots
SELECT 
  subregion1_name as state, 
  SUM(cumulative_confirmed) AS total_confirmed_cases 
FROM
  `bigquery-public-data.covid19_open_data.covid19_open_data` 
WHERE
  country_name="United States of America" 
  AND date='2020-05-15' 
  AND subregion1_name is NOT NULL
GROUP BY
  subregion1_name
HAVING
  total_confirmed_cases > 1500
ORDER BY
 total_confirmed_cases DESC


-- Task 4. Fatality ratio
SELECT
  SUM(cumulative_confirmed) AS total_confirmed_cases,
  SUM(cumulative_deceased) AS total_deaths,
  (SUM(cumulative_deceased)/SUM(cumulative_confirmed))*100 AS case_fatality_ratio
FROM
  `bigquery-public-data.covid19_open_data.covid19_open_data`
WHERE
  date BETWEEN '2020-04-01' AND '2020-04-30'
  AND country_name='Italy'
GROUP BY
  country_name


-- Task 5. Identifying specific day
SELECT
  date
FROM
  `bigquery-public-data.covid19_open_data.covid19_open_data`
WHERE
  country_name='Italy'
  AND cumulative_deceased > 12000
GROUP BY
  country_name, date, cumulative_deceased
ORDER BY
  date 
LIMIT 1


-- Task 6. Finding days with zero net new cases
WITH india_cases_by_date AS (
  SELECT
    date,
    SUM(cumulative_confirmed) AS cases
  FROM
    `bigquery-public-data.covid19_open_data.covid19_open_data`
  WHERE
    country_name="India"
    AND date between '2020-02-21' and '2020-03-14'
  GROUP BY
    date
  ORDER BY
    date ASC
 )

, india_previous_day_comparison AS (
  SELECT
    date,
    cases,
    LAG(cases) OVER(ORDER BY date) AS previous_day,
    cases - LAG(cases) OVER(ORDER BY date) AS net_new_cases
  FROM 
    india_cases_by_date
)

SELECT
  COUNT(net_new_cases) AS number
FROM
  india_previous_day_comparison
WHERE
  net_new_cases = 0


-- Task 7. Doubling rate
WITH us_cases_by_date AS (
  SELECT
    date,
    SUM(cumulative_confirmed) AS cases
  FROM
    `bigquery-public-data.covid19_open_data.covid19_open_data`
  WHERE
    country_name="United States of America"
    AND date between '2020-03-22' and '2020-04-20'
  GROUP BY
    date
  ORDER BY
    date ASC
 )

, us_previous_day_comparison AS(
  SELECT
    date,
    cases,
    LAG(cases) OVER(ORDER BY date) AS previous_day,
    cases - LAG(cases) OVER(ORDER BY date))/(LAG(cases) OVER(ORDER BY date))*100 AS change_percentage
  FROM
    us_cases_by_date
)

SELECT
  date AS Date,
  cases AS Confirmed_Cases_On_Day, 
  previous_day AS Confirmed_Cases_Previous_Day,
  change_percentage AS Percentage_Increase_In_Cases
FROM
  us_previous_day_comparison
WHERE
  change_percentage > 5


-- Task 8. Recovery rate
WITH cases_by_country AS (
  SELECT
    country_name AS country,
    SUM(cumulative_confirmed) AS confirmed_cases,
    SUM(cumulative_recovered) AS recovered_cases
  FROM
    `bigquery-public-data.covid19_open_data.covid19_open_data`
  WHERE
    date = '2020-05-10'
  GROUP BY
    country_name
 )

, summary AS ( 
  SELECT
    country, confirmed_cases, recovered_cases,
    recovered_cases * 100)/confirmed_cases AS recovery_rate
  FROM
    cases_by_country
)

SELECT 
  country, confirmed_cases,
  recovered_cases, recovery_rate
FROM
  summary
WHERE
  confirmed_cases > 50000
ORDER BY
  recovery_rate DESC
LIMIT 10


-- Task 9. CDGR - Cumulative daily growth rate
WITH
  france_cases AS (
  SELECT
    date,
    SUM(cumulative_confirmed) AS total_cases
  FROM
    `bigquery-public-data.covid19_open_data.covid19_open_data`
  WHERE
    country_name="France"
    AND date IN ('2020-01-24', '2020-05-15')
  GROUP BY
    date
  ORDER BY
    date DESC)

, summary AS (
SELECT
  total_cases AS first_day_cases,
  LEAD(total_cases) OVER(ORDER BY date) AS last_day_cases,
  DATE_DIFF(LEAD(date) OVER(ORDER BY date),date, day) AS days_diff
FROM
  france_cases
LIMIT 1
)

SELECT
  first_day_cases, last_day_cases, days_diff, 
  POW((last_day_cases/first_day_cases),(1/days_diff))-1 AS cdgr
FROM
  summary


-- Task 10. Create a Looker Studio report
SELECT
  date,
  SUM(cumulative_confirmed) AS country_cases,
  SUM(cumulative_deceased) AS country_deaths
FROM
  `bigquery-public-data.covid19_open_data.covid19_open_data`
WHERE
  country_name="United States of America"
  AND
  date BETWEEN "2020-03-17" AND "2020-04-28"
GROUP BY
  date