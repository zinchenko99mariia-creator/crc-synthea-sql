-- 01_load.sql
-- Load Synthea CSV files into a DuckDB database (crc.duckdb).
-- Before running: change DATA_PATH below to your local data folder.
-- DuckDB version: 1.5.6

-- Data folder (edit this path):
-- /Users/mariazinchenko/Desktop/project crc/crc_synthea_data/

CREATE OR REPLACE TABLE patients AS
SELECT * FROM read_csv('/Users/mariazinchenko/Desktop/project crc/crc_synthea_data/patients.csv');

CREATE OR REPLACE TABLE encounters AS
SELECT * FROM read_csv('/Users/mariazinchenko/Desktop/project crc/crc_synthea_data/encounters.csv');

CREATE OR REPLACE TABLE conditions AS
SELECT * FROM read_csv('/Users/mariazinchenko/Desktop/project crc/crc_synthea_data/conditions.csv');

CREATE OR REPLACE TABLE procedures AS
SELECT * FROM read_csv('/Users/mariazinchenko/Desktop/project crc/crc_synthea_data/procedures.csv');

CREATE OR REPLACE TABLE medications AS
SELECT * FROM read_csv('/Users/mariazinchenko/Desktop/project crc/crc_synthea_data/medications.csv');

CREATE OR REPLACE TABLE observations AS
SELECT * FROM read_csv('/Users/mariazinchenko/Desktop/project crc/crc_synthea_data/observations.csv');

CREATE OR REPLACE TABLE careplans AS
SELECT * FROM read_csv('/Users/mariazinchenko/Desktop/project crc/crc_synthea_data/careplans.csv');

-- Check: number of rows in each table
SELECT 'patients' AS table_name, COUNT(*) AS n_rows FROM patients
UNION ALL SELECT 'encounters',   COUNT(*) FROM encounters
UNION ALL SELECT 'conditions',   COUNT(*) FROM conditions
UNION ALL SELECT 'procedures',   COUNT(*) FROM procedures
UNION ALL SELECT 'medications',  COUNT(*) FROM medications
UNION ALL SELECT 'observations', COUNT(*) FROM observations
UNION ALL SELECT 'careplans',    COUNT(*) FROM careplans;
