-- 02_data_quality.sql
-- Data quality checks. Raw tables are not modified.
-- Findings are recorded in comments and in README (Data quality section).

-------------------------------------------------------------
-- PATIENTS
-------------------------------------------------------------

-- 1. Duplicates: total rows vs unique patient IDs
-- Expected: both numbers are equal (no duplicates)
SELECT COUNT(*)           AS total_rows,
       COUNT(DISTINCT Id) AS unique_ids
FROM patients;

-- 2. Missing values in key columns
SELECT COUNT(*) - COUNT(BIRTHDATE) AS missing_birthdate,
       COUNT(*) - COUNT(DEATHDATE) AS missing_deathdate,  -- missing = patient is alive
       COUNT(*) - COUNT(GENDER)    AS missing_gender,
       COUNT(*) - COUNT(RACE)      AS missing_race,
       COUNT(*) - COUNT(ETHNICITY) AS missing_ethnicity,
       COUNT(*) - COUNT(INCOME)    AS missing_income
FROM patients;

-- 3. Date logic: death before birth, dates after the end of simulation
-- Expected: 0 in all columns
SELECT SUM(CASE WHEN DEATHDATE < BIRTHDATE            THEN 1 ELSE 0 END) AS death_before_birth,
       SUM(CASE WHEN BIRTHDATE > DATE '2026-11-19'    THEN 1 ELSE 0 END) AS birth_in_future,
       SUM(CASE WHEN DEATHDATE > DATE '2026-11-19'    THEN 1 ELSE 0 END) AS death_in_future
FROM patients;

-- 4. Age range by vital status
-- Age is calculated at death (deceased) or at 2026-11-19, the end of the
-- Synthea simulation (alive). A fixed date keeps results reproducible.
-- Finding: deceased patients include people who died before age 40
-- (Synthea keeps them and generates a replacement patient).
WITH patient_age AS (
    SELECT Id,
           DEATHDATE,
           CASE
               WHEN DEATHDATE IS NOT NULL THEN date_sub('year', BIRTHDATE, DEATHDATE)
               ELSE date_sub('year', BIRTHDATE, DATE '2026-11-19')
           END AS age
    FROM patients
)
SELECT CASE WHEN DEATHDATE IS NULL THEN 'alive' ELSE 'deceased' END AS vital_status,
       COUNT(*)  AS n,
       MIN(age)  AS min_age,
       MAX(age)  AS max_age
FROM patient_age
GROUP BY vital_status;

-- 5. Income: range and implausible values
SELECT MIN(INCOME)                                   AS min_income,
       MAX(INCOME)                                   AS max_income,
       SUM(CASE WHEN INCOME <= 0 THEN 1 ELSE 0 END)  AS n_zero_or_negative
FROM patients;
