-- 05_descriptive.sql
-- Descriptive statistics.

-------------------------------------------------------------
-- PATIENTS (all patients, to be repeated for the study population)
-------------------------------------------------------------

-- Sex
SELECT GENDER,
       COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM patients), 1) AS pct
FROM patients
GROUP BY GENDER
ORDER BY n DESC;

-- Race
SELECT RACE,
       COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM patients), 1) AS pct
FROM patients
GROUP BY RACE
ORDER BY n DESC;

-- Ethnicity
SELECT ETHNICITY,
       COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM patients), 1) AS pct
FROM patients
GROUP BY ETHNICITY
ORDER BY n DESC;

-- Age: min, max, mean, median
WITH patient_age AS (
    SELECT Id,
           CASE
               WHEN DEATHDATE IS NOT NULL THEN date_sub('year', BIRTHDATE, DEATHDATE)
               ELSE date_sub('year', BIRTHDATE, DATE '2026-11-19')
           END AS age
    FROM patients
)
SELECT MIN(age)           AS min_age,
       MAX(age)           AS max_age,
       ROUND(AVG(age), 1) AS mean_age,
       MEDIAN(age)        AS median_age
FROM patient_age;

-- Income (median is preferred: the distribution is skewed)
SELECT MIN(INCOME)           AS min_income,
       MAX(INCOME)           AS max_income,
       ROUND(AVG(INCOME), 0) AS mean_income,
       MEDIAN(INCOME)        AS median_income
FROM patients;
