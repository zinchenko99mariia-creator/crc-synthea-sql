-- 04_cohort_crc.sql
-- Build the colorectal cancer (CRC) cohort.
-- Result: table crc_cohort_final, one row per patient with CRC.

-------------------------------------------------------------
-- Step 1. Find colorectal diagnoses in the conditions table
-------------------------------------------------------------
-- One row in conditions = one episode of a diagnosis (START-STOP).
-- n_records > n_patients means some patients have repeated episodes (e.g. recurrent polyps).
SELECT DESCRIPTION,
       CODE,
       COUNT(*)                AS n_records,
       COUNT(DISTINCT PATIENT) AS n_patients
FROM conditions
WHERE DESCRIPTION ILIKE '%colon%'
   OR DESCRIPTION ILIKE '%rect%'
   OR DESCRIPTION ILIKE '%colorectal%'
GROUP BY DESCRIPTION, CODE
ORDER BY n_patients DESC;

-- In the Synthea colorectal cancer module, the four cancer codes correspond to stages:
--   93761005  Primary malignant neoplasm of colon       -> stage I
--   109838007 Overlapping malignant neoplasm of colon   -> stage II
--   363406005 Malignant neoplasm of colon               -> stage III
--   94260004  Metastatic malignant neoplasm to colon    -> stage IV

-------------------------------------------------------------
-- Step 2. CRC cohort: first CRC diagnosis per patient
-------------------------------------------------------------
-- Date and stage are taken at the FIRST diagnosis:
-- AJCC stage is assigned at initial diagnosis, and risk factors must precede disease onset.
CREATE OR REPLACE TABLE crc_cohort AS
WITH crc_diagnoses AS (
    SELECT PATIENT,
           START,
           DESCRIPTION,
           ROW_NUMBER() OVER (PARTITION BY PATIENT ORDER BY START) AS rn
    FROM conditions
    WHERE DESCRIPTION IN (
        'Primary malignant neoplasm of colon (disorder)',
        'Overlapping malignant neoplasm of colon (disorder)',
        'Malignant neoplasm of colon (disorder)',
        'Metastatic malignant neoplasm to colon (disorder)'
    )
)
SELECT PATIENT,
       START AS diagnosis_date,
       CASE
           WHEN DESCRIPTION = 'Primary malignant neoplasm of colon (disorder)'     THEN 'I'
           WHEN DESCRIPTION = 'Overlapping malignant neoplasm of colon (disorder)' THEN 'II'
           WHEN DESCRIPTION = 'Malignant neoplasm of colon (disorder)'             THEN 'III'
           WHEN DESCRIPTION = 'Metastatic malignant neoplasm to colon (disorder)'  THEN 'IV'
       END AS stage
FROM crc_diagnoses
WHERE rn = 1;

-- Check: one row per patient (both numbers should be equal)
SELECT COUNT(*)                AS n_rows,
       COUNT(DISTINCT PATIENT) AS n_patients
FROM crc_cohort;

-- Number of patients by stage
SELECT stage, COUNT(*) AS n_patients
FROM crc_cohort
GROUP BY stage
ORDER BY stage;

-------------------------------------------------------------
-- Step 3. Add demographics and age at diagnosis
-------------------------------------------------------------
-- date_sub counts complete years (date_diff would count year boundaries).
CREATE OR REPLACE TABLE crc_cohort_demo AS
SELECT c.PATIENT,
       c.diagnosis_date,
       c.stage,
       p.GENDER,
       p.RACE,
       p.BIRTHDATE,
       p.DEATHDATE,
       p.INCOME,
       date_sub('year', p.BIRTHDATE, c.diagnosis_date) AS age_at_diagnosis
FROM crc_cohort AS c
JOIN patients AS p
  ON c.PATIENT = p.Id;

-- Age at diagnosis
SELECT MIN(age_at_diagnosis)    AS min_age,
       MAX(age_at_diagnosis)    AS max_age,
       MEDIAN(age_at_diagnosis) AS median_age
FROM crc_cohort_demo;

-------------------------------------------------------------
-- Step 4. Restrict to the study population (reached age 40)
-------------------------------------------------------------
-- age_at_end = age at death or at 2026-11-19 (end of simulation).
-- Patients who died before 40 are not part of the study population.
-- Decision: patients diagnosed before 40 (early-onset CRC) are KEPT,
-- if they reached age 40.
CREATE OR REPLACE TABLE crc_cohort_final AS
WITH ages AS (
    SELECT *,
           CASE
               WHEN DEATHDATE IS NOT NULL THEN date_sub('year', BIRTHDATE, DEATHDATE)
               ELSE date_sub('year', BIRTHDATE, DATE '2026-11-19')
           END AS age_at_end
    FROM crc_cohort_demo
)
SELECT *
FROM ages
WHERE age_at_end >= 40;

-- Summary of cohort selection
SELECT (SELECT COUNT(*) FROM crc_cohort_demo)                            AS crc_all,
       (SELECT COUNT(*) FROM crc_cohort_demo) - COUNT(*)                 AS excluded_died_before_40,
       COUNT(*)                                                         AS crc_final,
       SUM(CASE WHEN age_at_diagnosis < 40 THEN 1 ELSE 0 END)            AS early_onset_included
FROM crc_cohort_final;
-- Result: 258 CRC patients, 1 excluded, 257 in the final cohort, 6 early-onset cases included.
