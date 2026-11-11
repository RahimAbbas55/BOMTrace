-- DEV ONLY: drops every BOMTrace object and all data. Rebuild with 01 to 04.
BEGIN
  -- tables, children before parents
  FOR t IN (
    SELECT column_value AS table_name
    FROM TABLE(sys.odcivarchar2list(
      'AUDIT_LOG', 'APPROVALS', 'CHANGE_ORDER_ITEMS', 'CHANGE_ORDERS',
      'BOM_LINES', 'ITEMS', 'USERS'
    ))
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
    EXCEPTION
      WHEN OTHERS THEN
        -- ORA-00942: table does not exist, fine on a clean schema
        IF SQLCODE != -942 THEN RAISE; END IF;
    END;
  END LOOP;

  -- the package arrives in a later commit
  BEGIN
    EXECUTE IMMEDIATE 'DROP PACKAGE plm_pkg';
  EXCEPTION
    WHEN OTHERS THEN
      -- ORA-04043: object does not exist
      IF SQLCODE != -4043 THEN RAISE; END IF;
  END;

  BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE co_number_seq';
  EXCEPTION
    WHEN OTHERS THEN
      -- ORA-02289: sequence does not exist
      IF SQLCODE != -2289 THEN RAISE; END IF;
      BEGIN
    EXECUTE IMMEDIATE 'DROP PACKAGE plm_audit';
  EXCEPTION
    WHEN OTHERS THEN
      -- ORA-04043: object does not exist
      IF SQLCODE != -4043 THEN RAISE; END IF;
  END;
  END;
END;
/