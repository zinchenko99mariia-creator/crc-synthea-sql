-- 06_analysis_table.sql
-- Build the analysis table: the whole study population (reached age 40),
-- CRC status, index date and risk factors. One row per patient.
-- Requires tables from 01_load.sql and 04_cohort_crc.sql (crc_cohort_final).

-------------------------------------------------------------
-- Step 1. Study population with CRC flag and index date
-------------------------------------------------------------
-- Study population: patients who reached age 40
-- (age at death or at 2026-11-19, the end of the Synthea simulation).
-- LEFT JOIN keeps all patients. has_crc = 1 if the patient is in crc_cohort_final.
-- Index date (reference point for risk factors):
--   CRC cases     -> date of first CRC diagnosis
--   non-cases     -> date of death, or 2026-11-19 if alive
CREATE OR REPLACE TABLE study_population AS
WITH ages AS (
    SELECT Id AS PATIENT, GENDER, RACE, ETHNICITY, INCOME, BIRTHDATE, DEATHDATE,
           CASE
               WHEN DEATHDATE IS NOT NULL THEN date_sub('year', BIRTHDATE, DEATHDATE)
               ELSE date_sub('year', BIRTHDATE, DATE '2026-11-19')
           END AS age_at_end
    FROM patients
)
SELECT a.*,
       CASE WHEN c.PATIENT IS NOT NULL THEN 1 ELSE 0 END AS has_crc,
       c.diagnosis_date,
       c.stage,
       c.age_at_diagnosis,
       CASE
           WHEN c.PATIENT IS NOT NULL   THEN c.diagnosis_date
           WHEN a.DEATHDATE IS NOT NULL THEN a.DEATHDATE
           ELSE DATE '2026-11-19'
       END AS index_date
FROM ages AS a
LEFT JOIN crc_cohort_final AS c
  ON a.PATIENT = c.PATIENT
WHERE a.age_at_end >= 40;

-- Check: expected 6541 patients (257 with CRC)
SELECT has_crc, COUNT(*) AS n
FROM study_population
GROUP BY has_crc
ORDER BY has_crc;

-------------------------------------------------------------
-- Step 2. Risk factors from observations (smoking, BMI)
-------------------------------------------------------------
-- For each patient and each factor, take the LAST measurement
-- STRICTLY BEFORE the index date (risk factors must precede the outcome,
-- measurements on the day of diagnosis may already reflect the disease).
-- Long format (one row per measurement) is pivoted to wide format
-- (one row per patient, one column per factor).
-- VALUE is stored as text, so BMI is converted to a number with CAST.
-- AUDIT-C (alcohol) is not used: 34% of CRC cases had no AUDIT-C value
-- before diagnosis (above the 15% missing-data threshold).
CREATE OR REPLACE TABLE risk_factors AS
WITH last_obs AS (
    SELECT o.PATIENT,
           o.DESCRIPTION,
           o.VALUE,
           ROW_NUMBER() OVER (PARTITION BY o.PATIENT, o.DESCRIPTION
                              ORDER BY o.DATE DESC) AS rn
    FROM observations AS o
    JOIN study_population AS s
      ON o.PATIENT = s.PATIENT
    WHERE o.DESCRIPTION IN ('Tobacco smoking status',
                            'Body mass index (BMI) [Ratio]')
      AND o.DATE < s.index_date
)
SELECT PATIENT,
       MAX(CASE WHEN DESCRIPTION = 'Tobacco smoking status'        THEN VALUE END)                 AS smoking_status,
       MAX(CASE WHEN DESCRIPTION = 'Body mass index (BMI) [Ratio]' THEN CAST(VALUE AS DOUBLE) END) AS bmi
FROM last_obs
WHERE rn = 1
GROUP BY PATIENT;

-- Check: one row per patient
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT PATIENT) AS n_patients
FROM risk_factors;

-------------------------------------------------------------
-- Step 3. Analysis table: population + risk factors + type 2 diabetes
-------------------------------------------------------------
-- has_diabetes = 1 if type 2 diabetes was diagnosed before the index date.
-- in_analysis = 1 if smoking status and BMI are available.
-- Patients are not deleted, only flagged: analyses use WHERE in_analysis = 1.
-- Imputation was not used: all missing values were among CRC cases
-- (missingness is not random).
CREATE OR REPLACE TABLE analysis_table AS
WITH diabetes AS (
    SELECT DISTINCT c.PATIENT
    FROM conditions AS c
    JOIN study_population AS s
      ON c.PATIENT = s.PATIENT
    WHERE c.DESCRIPTION = 'Diabetes mellitus type 2 (disorder)'
      AND c.START < s.index_date
)
SELECT s.*,
       r.smoking_status,
       r.bmi,
       CASE WHEN d.PATIENT IS NOT NULL THEN 1 ELSE 0 END AS has_diabetes,
       CASE WHEN r.smoking_status IS NOT NULL AND r.bmi IS NOT NULL THEN 1 ELSE 0 END AS in_analysis
FROM study_population AS s
LEFT JOIN risk_factors AS r
  ON s.PATIENT = r.PATIENT
LEFT JOIN diabetes AS d
  ON s.PATIENT = d.PATIENT;

-- Summary: missing risk factor data by CRC status
SELECT has_crc,
       COUNT(*)                                         AS n_total,
       SUM(in_analysis)                                 AS n_in_analysis,
       COUNT(*) - SUM(in_analysis)                      AS n_excluded_missing,
       SUM(has_diabetes)                                AS n_diabetes
FROM analysis_table
GROUP BY has_crc
ORDER BY has_crc;
-- Result: non-CRC 6284 (all included), CRC 257, 226 included, 31 excluded.
-- Analysis sample: 6510 patients.
