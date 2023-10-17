-- My solution to Predict Soccer Match Outcomes with BigQuery ML Challenge Lab

-- Task 2. Analyze soccer data
SELECT
  playerId,
  (Players.firstName || ' ' || Players.lastName) AS playerName,
  COUNT(id) AS numPKAtt,
  SUM(IF(101 IN UNNEST(tags.id), 1, 0)) AS numPKGoals,
  SAFE_DIVIDE(
    SUM(IF(101 IN UNNEST(tags.id), 1, 0)),
    COUNT(id)
    ) AS PKSuccessRate
FROM
  `soccer.events513` Events
LEFT JOIN
  `soccer.players` Players ON
  Events.playerId = Players.wyId
WHERE
  eventName = 'Free Kick' AND
  subEventName = 'Penalty'
GROUP BY
  playerId, playerName
HAVING
  numPkAtt >= 5
ORDER BY
  PKSuccessRate DESC, numPKAtt DESC
 
 
 -- Task 3. Gain insight by analyzing soccer data
 WITH Shots AS
(
SELECT
  *,

  /* 101 is known Tag for 'goals' from goals table */
  (101 IN UNNEST(tags.id)) AS isGoal,

  /* Translate 0-100 (x,y) coordinate-based distances to absolute positions
  using "average" field dimensions of 105x68 before combining in 2D dist calc */
  SQRT(
    POW(
      (90 - positions[ORDINAL(1)].x) * 119/100,
      2) +
    POW(
      (45 - positions[ORDINAL(1)].y) * 60/100,
      2)
     ) AS shotDistance
 FROM
  `soccer.events513`
 WHERE
  /* Includes both "open play" & free kick shots (including penalties) */
  eventName = 'Shot' OR
  (eventName = 'Free Kick' AND subEventName IN ('Free kick shot', 'Penalty'))
)

SELECT
  ROUND(shotDistance, 0) AS ShotDistRound0,
  COUNT(*) AS numShots,
  SUM(IF(isGoal, 1, 0)) AS numGoals,
  AVG(IF(isGoal, 1, 0)) AS goalPct
FROM
  Shots
WHERE
  shotDistance <= 50
GROUP BY
  ShotDistRound0
ORDER BY
  ShotDistRound0
 
 
-- Task 4. Create a regression model using soccer data

-- Create a function to calculate shot distance from (x,y) coordinates
CREATE FUNCTION `soccer.GetShotDistanceToGoal513`(x INT64, y INT64)
RETURNS FLOAT64
AS (
  /* Translate 0-100 (x,y) coordinate-based distances to absolute positions
  using "average" field dimensions of 119x60 before combining in 2D dist calc */
  SQRT(
    POW((90 - x) * 119/100, 2) +
    POW((45 - y) * 60/100, 2)
    )
);
 
 -- Create a function to calculate shot angle from (x,y) coordinates
CREATE FUNCTION `soccer.GetShotAngleToGoal513`(x INT64, y INT64)
RETURNS FLOAT64
AS (
  SAFE.ACOS(
   /* Have to translate 0-100 (x,y) coordinates to absolute positions using
   "average" field dimensions of 119x60 before using in various distance calcs */
    SAFE_DIVIDE(
      ( /* Squared distance between shot and 1 post, in meters */
        (POW(119 - (x * 119/100), 2) + POW(30 + (7.32/2) - (y * 60/100), 2)) +
        /* Squared distance between shot and other post, in meters */
        (POW(119 - (x * 119/100), 2) + POW(30 - (7.32/2) - (y * 60/100), 2)) -
        /* Squared length of goal opening, in meters */
        POW(7.32, 2)
      ),
      (2 *
        /* Distance between shot and 1 post, in meters */
        SQRT(POW(119 - (x * 119/100), 2) + POW(30 + 7.32/2 - (y * 60/100), 2)) *
        /* Distance between shot and other post, in meters */
        SQRT(POW(119 - (x * 119/100), 2) + POW(30 - 7.32/2 - (y * 60/100), 2))
      )
    )
  /* Translate radians to degrees */
  ) * 180 / ACOS(-1)
 );

-- Create an expected goals model
CREATE MODEL `soccer.xg_logistic_reg_model_513`
OPTIONS(
  model_type = 'LOGISTIC_REG',
  input_label_cols = ['isGoal']
 ) AS
SELECT
  Events.subEventName AS shotType,
  /* 101 is known Tag for 'goals' from goals table */
  (101 IN UNNEST(Events.tags.id)) AS isGoal,
  `soccer.GetShotDistanceToGoal513`(Events.positions[ORDINAL(1)].x,
    Events.positions[ORDINAL(1)].y) AS shotDistance,
  `soccer.GetShotAngleToGoal513`(Events.positions[ORDINAL(1)].x,
    Events.positions[ORDINAL(1)].y) AS shotAngle
FROM
  `soccer.events513` Events
LEFT JOIN
  `soccer.matches` Matches ON
  Events.matchId = Matches.wyId
LEFT JOIN
  `soccer.competitions` Competitions ON
  Matches.competitionId = Competitions.wyId
WHERE
  /* Filter out World Cup matches for model fitting purposes */
  Competitions.name != 'World Cup' AND
  /* Includes both "open play" & free kick shots (including penalties) */
  (
    eventName = 'Shot' OR
    (eventName = 'Free Kick' AND subEventName IN ('Free kick shot', 'Penalty'))
  );


-- Task 5. Make predictions from new data with the BigQuery model
SELECT
  *
FROM
  ML.PREDICT(
    MODEL `soccer.xg_logistic_reg_model_513`,   
    (
      SELECT
        Events.subEventName AS shotType,
        /* 101 is known Tag for 'goals' from goals table */
        (101 IN UNNEST(Events.tags.id)) AS isGoal,
        `soccer.GetShotDistanceToGoal513`(Events.positions[ORDINAL(1)].x,
          Events.positions[ORDINAL(1)].y) AS shotDistance,
        `soccer.GetShotAngleToGoal513`(Events.positions[ORDINAL(1)].x,
          Events.positions[ORDINAL(1)].y) AS shotAngle
      FROM
        `soccer.events513` Events
      LEFT JOIN
        `soccer.matches` Matches ON
        Events.matchId = Matches.wyId
      LEFT JOIN
        `soccer.competitions` Competitions ON
        Matches.competitionId = Competitions.wyId
      WHERE
        /* Look only at World Cup matches for model predictions */
        Competitions.name = 'World Cup' AND
        /* Includes both "open play" & free kick shots (including penalties) */
        (
          eventName = 'Shot' OR
          (eventName = 'Free Kick' AND subEventName IN ('Free kick shot', 'Penalty'))
        )
    )
  );
