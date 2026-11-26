-- 05_descriptive.sql
-- Description of the analysis sample by CRC status ("Table 1").
-- Requires: 04_analysis_table.sql
-- Analysis sample: in_analysis = 1 (6510 patients: 226 with CRC, 6284 without CRC).

-------------------------------------------------------------
-- Numbers of patients and age
-------------------------------------------------------------
SELECT has_crc,
       COUNT(*)                    AS n,
       ROUND(AVG(age_at_index), 1) AS mean_age,
       MEDIAN(age_at_index)        AS median_age,
       MIN(age_at_index)           AS min_age,
       MAX(age_at_index)           AS max_age
FROM analysis_table
WHERE in_analysis = 1
GROUP BY has_crc
ORDER BY has_crc;

-------------------------------------------------------------
-- Categorical variables: n and % within each CRC group
-------------------------------------------------------------
-- The denominator is the number of patients in the CRC group (has_crc = 0 or 1),
-- calculated with a window function: SUM(COUNT(*)) OVER (PARTITION BY has_crc).

-- Sex
SELECT has_crc,
       GENDER,
       COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY has_crc), 1) AS pct
FROM analysis_table
WHERE in_analysis = 1
GROUP BY has_crc, GENDER
ORDER BY has_crc, GENDER;

-- Age group
SELECT has_crc,
       age_group,
       COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY has_crc), 1) AS pct
FROM analysis_table
WHERE in_analysis = 1
GROUP BY has_crc, age_group
ORDER BY has_crc, age_group;

-- Race
SELECT has_crc,
       RACE,
       COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY has_crc), 1) AS pct
FROM analysis_table
WHERE in_analysis = 1
GROUP BY has_crc, RACE
ORDER BY has_crc, n DESC;

-- Smoking
SELECT has_crc,
       smoking,
       COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY has_crc), 1) AS pct
FROM analysis_table
WHERE in_analysis = 1
GROUP BY has_crc, smoking
ORDER BY has_crc, smoking;

-- BMI category
SELECT has_crc,
       bmi_category,
       COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY has_crc), 1) AS pct
FROM analysis_table
WHERE in_analysis = 1
GROUP BY has_crc, bmi_category
ORDER BY has_crc, bmi_category;

-- Type 2 diabetes
SELECT has_crc,
       has_diabetes,
       COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY has_crc), 1) AS pct
FROM analysis_table
WHERE in_analysis = 1
GROUP BY has_crc, has_diabetes
ORDER BY has_crc, has_diabetes;

-------------------------------------------------------------
-- Continuous variables: BMI and income
-------------------------------------------------------------
-- Median is shown for income because the distribution is skewed.
SELECT has_crc,
       ROUND(AVG(bmi), 1)    AS mean_bmi,
       ROUND(MEDIAN(bmi), 1) AS median_bmi,
       MEDIAN(INCOME)        AS median_income
FROM analysis_table
WHERE in_analysis = 1
GROUP BY has_crc
ORDER BY has_crc;
