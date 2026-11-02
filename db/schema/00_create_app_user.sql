-- run the sql once in the ADB admin console to create the app_user table
CREATE USER plm_app IDENTIFIED BY "&app_password"
  DEFAULT TABLESPACE data
  QUOTA UNLIMITED ON data;
GRANT CREATE SESSION,
      CREATE TABLE,
      CREATE VIEW,
      CREATE SEQUENCE,
      CREATE PROCEDURE,
      CREATE TRIGGER,
      CREATE TYPE
  TO plm_app;