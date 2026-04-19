-- DESTRUCTIVE. Drops the entire MA_PAYER database and WH_XS warehouse.
-- Use only for the reproducibility test (see docs/rebuild-from-scratch.md).
-- Run as ACCOUNTADMIN.

USE ROLE ACCOUNTADMIN;

DROP DATABASE IF EXISTS MA_PAYER;
DROP WAREHOUSE IF EXISTS WH_XS;

-- Role separation objects (only present if sql/03_create_roles.sql was run)
DROP USER IF EXISTS DBT_SVC;
DROP USER IF EXISTS APP_SVC;
DROP ROLE IF EXISTS MA_PAYER_DEV;
DROP ROLE IF EXISTS MA_PAYER_VIEWER;

-- All three should return 0 rows
SHOW DATABASES  LIKE 'MA_PAYER';
SHOW WAREHOUSES LIKE 'WH_XS';
SHOW ROLES      LIKE 'MA_PAYER_%';
