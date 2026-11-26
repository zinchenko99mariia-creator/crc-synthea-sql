-- 06_prevalence.sql
-- Main question: how does the prevalence of CRC differ by demographic,
-- lifestyle and clinical characteristics among adults aged 40+?
-- Requires: 04_analysis_table.sql
-- Analysis sample: in_analysis = 1 (6510 patients, 226 with CRC).
--
-- has_crc is 0 or 1, so within each group:
--   COUNT(*)     = all patients (denominator)
--   SUM(has_crc) = patients with CRC (numerator)
--   AVG(has_crc) = proportion with CRC
-- These are crude (unadjusted) proportions. Differences between groups are
-- descriptive and may be confounded (for example, by age).

-------------------------------------------------------------
-- Overall prevalence
-------------------------------------------------------------
SELECT COUNT(*)                       AS n_total,
       SUM(has_crc)                   AS n_crc,
       ROUND(100.0 * AVG(has_crc), 1) AS crc_pct
FROM analysis_table
WHERE in_analysis = 1;

-------------------------------------------------------------
-- Prevalence by single factors
-------------------------------------------------------------

-- Sex
SELECT GENDER,
       COUNT(*)                       AS n_total,
       SUM(has_crc)                   AS n_crc,
       ROUND(100.0 * AVG(has_crc), 1) AS crc_pct
FROM analysis_table
WHERE in_analysis = 1
GROUP BY GENDER
ORDER BY GENDER;

-- Age group (age at index date)
SELECT age_group,
       COUNT(*)                       AS n_total,
       SUM(has_crc)                   AS n_crc,
       ROUND(100.0 * AVG(has_crc), 1) AS crc_pct
FROM analysis_table
WHERE in_analysis = 1
GROUP BY age_group
ORDER BY age_group;

-- Race
SELECT RACE,
       COUNT(*)                       AS n_total,
       SUM(has_crc)                   AS n_crc,
       ROUND(100.0 * AVG(has_crc), 1) AS crc_pct
FROM analysis_table
WHERE in_analysis = 1
GROUP BY RACE
ORDER BY n_total DESC;

-- Ethnicity
SELECT ETHNICITY,
       COUNT(*)                       AS n_total,
       SUM(has_crc)                   AS n_crc,
       ROUND(100.0 * AVG(has_crc), 1) AS crc_pct
FROM analysis_table
WHERE in_analysis = 1
GROUP BY ETHNICITY
ORDER BY ETHNICITY;

-- Income quartile (1 = lowest income)
SELECT income_quartile,
       MIN(INCOME)                    AS min_income,
       MAX(INCOME)                    AS max_income,
       COUNT(*)                       AS n_total,
       SUM(has_crc)                   AS n_crc,
       ROUND(100.0 * AVG(has_crc), 1) AS crc_pct
FROM analysis_table
WHERE in_analysis = 1
GROUP BY income_quartile
ORDER BY income_quartile;

-- Smoking
SELECT smoking,
       COUNT(*)                       AS n_total,
       SUM(has_crc)                   AS n_crc,
       ROUND(100.0 * AVG(has_crc), 1) AS crc_pct
FROM analysis_table
WHERE in_analysis = 1
GROUP BY smoking
ORDER BY smoking;

-- BMI category (sorted from lowest to highest BMI)
SELECT bmi_category,
       COUNT(*)                       AS n_total,
       SUM(has_crc)                   AS n_crc,
       ROUND(100.0 * AVG(has_crc), 1) AS crc_pct
FROM analysis_table
WHERE in_analysis = 1
GROUP BY bmi_category
ORDER BY MIN(bmi);

-- Type 2 diabetes
SELECT has_diabetes,
       COUNT(*)                       AS n_total,
       SUM(has_crc)                   AS n_crc,
       ROUND(100.0 * AVG(has_crc), 1) AS crc_pct
FROM analysis_table
WHERE in_analysis = 1
GROUP BY has_diabetes
ORDER BY has_diabetes;

-------------------------------------------------------------
-- Smoking by age group (a simple check for confounding by age)
-------------------------------------------------------------
-- If the difference between never and former smokers becomes smaller
-- within age groups, part of the crude difference is explained by age.
SELECT age_group,
       smoking,
       COUNT(*)                       AS n_total,
       SUM(has_crc)                   AS n_crc,
       ROUND(100.0 * AVG(has_crc), 1) AS crc_pct
FROM analysis_table
WHERE in_analysis = 1
GROUP BY age_group, smoking
ORDER BY age_group, smoking;

-------------------------------------------------------------
-- One long table with all results (for Power BI)
-------------------------------------------------------------
-- UNION ALL stacks the results for all factors into one table:
-- factor | category | n_total | n_crc | crc_pct
CREATE OR REPLACE TABLE prevalence_by_group AS
SELECT 'Sex' AS factor, GENDER AS category,
       COUNT(*) AS n_total, SUM(has_crc) AS n_crc, ROUND(100.0 * AVG(has_crc), 1) AS crc_pct
FROM analysis_table WHERE in_analysis = 1 GROUP BY GENDER
UNION ALL
SELECT 'Age group', age_group,
       COUNT(*), SUM(has_crc), ROUND(100.0 * AVG(has_crc), 1)
FROM analysis_table WHERE in_analysis = 1 GROUP BY age_group
UNION ALL
SELECT 'Race', RACE,
       COUNT(*), SUM(has_crc), ROUND(100.0 * AVG(has_crc), 1)
FROM analysis_table WHERE in_analysis = 1 GROUP BY RACE
UNION ALL
SELECT 'Ethnicity', ETHNICITY,
       COUNT(*), SUM(has_crc), ROUND(100.0 * AVG(has_crc), 1)
FROM analysis_table WHERE in_analysis = 1 GROUP BY ETHNICITY
UNION ALL
SELECT 'Income quartile', 'Q' || CAST(income_quartile AS VARCHAR),
       COUNT(*), SUM(has_crc), ROUND(100.0 * AVG(has_crc), 1)
FROM analysis_table WHERE in_analysis = 1 GROUP BY income_quartile
UNION ALL
SELECT 'Smoking', smoking,
       COUNT(*), SUM(has_crc), ROUND(100.0 * AVG(has_crc), 1)
FROM analysis_table WHERE in_analysis = 1 GROUP BY smoking
UNION ALL
SELECT 'BMI category', bmi_category,
       COUNT(*), SUM(has_crc), ROUND(100.0 * AVG(has_crc), 1)
FROM analysis_table WHERE in_analysis = 1 GROUP BY bmi_category
UNION ALL
SELECT 'Type 2 diabetes', CASE WHEN has_diabetes = 1 THEN 'Yes' ELSE 'No' END,
       COUNT(*), SUM(has_crc), ROUND(100.0 * AVG(has_crc), 1)
FROM analysis_table WHERE in_analysis = 1 GROUP BY has_diabetes;

SELECT * FROM prevalence_by_group ORDER BY factor, category;
