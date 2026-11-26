-- 07_stage_treatment.sql
-- Secondary question: at which stage is CRC diagnosed, and how are patients treated?
-- Requires: 01_load.sql, 03_crc_cases.sql
-- Population: all 257 CRC cases (risk factor data are not needed here).

-------------------------------------------------------------
-- Step 1. Stage at diagnosis
-------------------------------------------------------------
SELECT stage,
       COUNT(*)                                            AS n,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS pct,
       ROUND(AVG(age_at_diagnosis), 1)                     AS mean_age_at_diagnosis
FROM crc_cases
GROUP BY stage
ORDER BY stage;
-- SUM(COUNT(*)) OVER () is a window function: the total number of cases,
-- used as the denominator for the percentage.

-------------------------------------------------------------
-- Step 2. Find CRC treatments
-------------------------------------------------------------
-- Treatments are identified by REASONDESCRIPTION (the reason for the procedure or
-- medication). This keeps only treatments given for colon cancer, not for other cancers.
SELECT 'procedure' AS source, DESCRIPTION, COUNT(DISTINCT PATIENT) AS n_patients
FROM procedures
WHERE REASONDESCRIPTION IN (
    'Primary malignant neoplasm of colon (disorder)',
    'Overlapping malignant neoplasm of colon (disorder)',
    'Malignant neoplasm of colon (disorder)',
    'Metastatic malignant neoplasm to colon (disorder)'
)
GROUP BY DESCRIPTION
UNION ALL
SELECT 'medication', DESCRIPTION, COUNT(DISTINCT PATIENT)
FROM medications
WHERE REASONDESCRIPTION IN (
    'Primary malignant neoplasm of colon (disorder)',
    'Overlapping malignant neoplasm of colon (disorder)',
    'Malignant neoplasm of colon (disorder)',
    'Metastatic malignant neoplasm to colon (disorder)'
)
GROUP BY DESCRIPTION
ORDER BY n_patients DESC;
-- Main treatments in the data:
--   surgery:      Partial resection of colon
--   chemotherapy: oxaliplatin + leucovorin (with combined chemotherapy and radiation therapy)

-------------------------------------------------------------
-- Step 3. Treatment flags for each CRC case
-------------------------------------------------------------
-- Flags (1/0): was the treatment given on or after the diagnosis date?
-- Outcomes: deceased (1/0) and months from diagnosis to death.
CREATE OR REPLACE TABLE crc_treatment AS
WITH surgery AS (
    SELECT DISTINCT p.PATIENT
    FROM procedures AS p
    JOIN crc_cases AS c
      ON p.PATIENT = c.PATIENT
    WHERE p.DESCRIPTION = 'Partial resection of colon (procedure)'
      AND p.REASONDESCRIPTION ILIKE '%neoplasm%colon%'
      AND p.START >= c.diagnosis_date
),
chemo AS (
    SELECT DISTINCT m.PATIENT
    FROM medications AS m
    JOIN crc_cases AS c
      ON m.PATIENT = c.PATIENT
    WHERE m.DESCRIPTION ILIKE '%oxaliplatin%'
      AND m.REASONDESCRIPTION ILIKE '%neoplasm%colon%'
      AND m.START >= c.diagnosis_date
)
SELECT c.PATIENT,
       c.stage,
       c.diagnosis_date,
       c.age_at_diagnosis,
       CASE WHEN s.PATIENT IS NOT NULL THEN 1 ELSE 0 END AS had_surgery,
       CASE WHEN ch.PATIENT IS NOT NULL THEN 1 ELSE 0 END AS had_chemo,
       CASE
           WHEN s.PATIENT IS NOT NULL AND ch.PATIENT IS NOT NULL THEN 'Surgery + chemotherapy'
           WHEN s.PATIENT IS NOT NULL                            THEN 'Surgery only'
           WHEN ch.PATIENT IS NOT NULL                           THEN 'Chemotherapy only'
           ELSE                                                       'No recorded treatment'
       END AS treatment_pattern,
       CASE WHEN p.DEATHDATE IS NOT NULL THEN 1 ELSE 0 END AS deceased,
       CASE
           WHEN p.DEATHDATE IS NOT NULL THEN date_sub('month', c.diagnosis_date, p.DEATHDATE)
       END AS months_to_death
FROM crc_cases AS c
JOIN patients AS p
  ON c.PATIENT = p.Id
LEFT JOIN surgery AS s
  ON c.PATIENT = s.PATIENT
LEFT JOIN chemo AS ch
  ON c.PATIENT = ch.PATIENT;

-- Check: one row per CRC case (expected 257)
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT PATIENT) AS n_patients
FROM crc_treatment;

-------------------------------------------------------------
-- Step 4. Treatment by stage
-------------------------------------------------------------
SELECT stage,
       COUNT(*)                              AS n,
       SUM(had_surgery)                      AS n_surgery,
       ROUND(100.0 * AVG(had_surgery), 1)    AS surgery_pct,
       SUM(had_chemo)                        AS n_chemo,
       ROUND(100.0 * AVG(had_chemo), 1)      AS chemo_pct
FROM crc_treatment
GROUP BY stage
ORDER BY stage;

-- Treatment pattern by stage
SELECT stage,
       treatment_pattern,
       COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY stage), 1) AS pct
FROM crc_treatment
GROUP BY stage, treatment_pattern
ORDER BY stage, n DESC;

-------------------------------------------------------------
-- Step 5. Deaths by stage
-------------------------------------------------------------
-- Deaths from any cause (cause of death is not available).
-- months_to_death is calculated only for deceased patients.
-- Follow-up time differs between patients, so these numbers are descriptive only.
SELECT stage,
       COUNT(*)                         AS n,
       SUM(deceased)                    AS n_deceased,
       ROUND(100.0 * AVG(deceased), 1)  AS deceased_pct,
       MEDIAN(months_to_death)          AS median_months_to_death
FROM crc_treatment
GROUP BY stage
ORDER BY stage;
