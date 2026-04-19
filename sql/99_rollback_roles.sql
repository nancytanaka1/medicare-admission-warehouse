-- Undo sql/03_create_roles.sql. Run as ACCOUNTADMIN.
-- Revert profiles.yml / connections.toml / secrets.toml back to your admin
-- account before (or right after) running this, or dbt and Streamlit will fail.

USE ROLE ACCOUNTADMIN;

REVOKE ROLE MA_PAYER_DEV    FROM USER DBT_SVC;
REVOKE ROLE MA_PAYER_VIEWER FROM USER APP_SVC;

DROP USER IF EXISTS DBT_SVC;
DROP USER IF EXISTS APP_SVC;

-- DROP ROLE auto-revokes all schema/table/warehouse/future grants
DROP ROLE IF EXISTS MA_PAYER_DEV;
DROP ROLE IF EXISTS MA_PAYER_VIEWER;

SHOW USERS LIKE 'DBT_SVC';
SHOW USERS LIKE 'APP_SVC';
SHOW ROLES LIKE 'MA_PAYER_%';
