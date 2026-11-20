-- 03_study_population.sql
-- Study population: patients who reached age 40
-- (age at death or at 2026-11-19 >= 40).
-- Patients who died before 40 had no chance of CRC screening and are excluded.

WITH patient_age AS (
    SELECT Id,
           CASE
               WHEN DEATHDATE IS NOT NULL THEN date_sub('year', BIRTHDATE, DEATHDATE)
               ELSE date_sub('year', BIRTHDATE, DATE '2026-11-19')
           END AS age
    FROM patients
)
SELECT CASE
           WHEN age >= 40 THEN '40+ (included)'
           ELSE '<40 (excluded)'
       END AS age_group,
       COUNT(*) AS n
FROM patient_age
GROUP BY age_group;
