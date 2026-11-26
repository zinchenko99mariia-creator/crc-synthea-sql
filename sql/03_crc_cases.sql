-- 03_crc_cases.sql
-- Identify colorectal cancer (CRC) cases.
-- Result: table crc_cases, one row per CRC patient who reached age 40.
-- Requires: 01_load.sql

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
-- All four codes are counted as CRC.

-------------------------------------------------------------
-- Step 2. All CRC cases: first diagnosis, stage, age
-------------------------------------------------------------
-- Diagnosis date and stage are taken at the FIRST CRC record (ROW_NUMBER, rn = 1):
-- AJCC stage is assigned at initial diagnosis, and risk factors must precede disease onset.
-- age_at_diagnosis: complete years from birth to diagnosis
--   (date_sub counts complete years, date_diff would count year boundaries).
-- age_at_end: age at death, or at 2026-11-19 (end of the Synthea simulation) if alive.
CREATE OR REPLACE TABLE crc_cases_all AS
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
SELECT d.PATIENT,
       d.START AS diagnosis_date,
       CASE
           WHEN d.DESCRIPTION = 'Primary malignant neoplasm of colon (disorder)'     THEN 'I'
           WHEN d.DESCRIPTION = 'Overlapping malignant neoplasm of colon (disorder)' THEN 'II'
           WHEN d.DESCRIPTION = 'Malignant neoplasm of colon (disorder)'             THEN 'III'
           WHEN d.DESCRIPTION = 'Metastatic malignant neoplasm to colon (disorder)'  THEN 'IV'
       END AS stage,
       date_sub('year', p.BIRTHDATE, d.START) AS age_at_diagnosis,
       CASE
           WHEN p.DEATHDATE IS NOT NULL THEN date_sub('year', p.BIRTHDATE, p.DEATHDATE)
           ELSE date_sub('year', p.BIRTHDATE, DATE '2026-11-19')
       END AS age_at_end
FROM crc_diagnoses AS d
JOIN patients AS p
  ON d.PATIENT = p.Id
WHERE d.rn = 1;

-- Check: one row per patient (both numbers should be equal)
SELECT COUNT(*)                AS n_rows,
       COUNT(DISTINCT PATIENT) AS n_patients
FROM crc_cases_all;

-- Age at diagnosis
SELECT MIN(age_at_diagnosis)    AS min_age,
       MAX(age_at_diagnosis)    AS max_age,
       MEDIAN(age_at_diagnosis) AS median_age
FROM crc_cases_all;

-------------------------------------------------------------
-- Step 3. Keep cases from the study population (reached age 40)
-------------------------------------------------------------
-- Patients who died before age 40 are not part of the study population.
-- Decision: patients diagnosed before 40 (early-onset CRC) are KEPT if they reached age 40.
CREATE OR REPLACE TABLE crc_cases AS
SELECT *
FROM crc_cases_all
WHERE age_at_end >= 40;

-- Summary of case selection
SELECT (SELECT COUNT(*) FROM crc_cases_all)                       AS crc_all,
       (SELECT COUNT(*) FROM crc_cases_all) - COUNT(*)            AS excluded_died_before_40,
       COUNT(*)                                                  AS crc_final,
       SUM(CASE WHEN age_at_diagnosis < 40 THEN 1 ELSE 0 END)     AS early_onset_included
FROM crc_cases;
-- Result: 258 CRC patients, 1 excluded, 257 CRC cases, 6 early-onset cases included.

-- Number of cases by stage
SELECT stage, COUNT(*) AS n_patients
FROM crc_cases
GROUP BY stage
ORDER BY stage;
