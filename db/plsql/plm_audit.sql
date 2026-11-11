CREATE OR REPLACE PACKAGE plm_audit AS
  -- sets the acting user for this database session, call it at the start of every request
  PROCEDURE set_user(p_user_id IN NUMBER);

  -- forgets the acting user, call it when the request is done
  PROCEDURE clear_user;

  FUNCTION get_user RETURN NUMBER;

  -- writes one audit row, called by the audit triggers with the old and new values as JSON
  PROCEDURE log_change(
    p_table_name IN VARCHAR2,
    p_record_id  IN NUMBER,
    p_action     IN VARCHAR2,
    p_before     IN CLOB,
    p_after      IN CLOB
  );
END plm_audit;
/

CREATE OR REPLACE PACKAGE BODY plm_audit AS

  -- package state lives as long as the database session
  g_user_id NUMBER;

  PROCEDURE set_user(p_user_id IN NUMBER) IS
  BEGIN
    g_user_id := p_user_id;
  END set_user;

  PROCEDURE clear_user IS
  BEGIN
    g_user_id := NULL;
  END clear_user;

  FUNCTION get_user RETURN NUMBER IS
  BEGIN
    RETURN g_user_id;
  END get_user;

  PROCEDURE log_change(
    p_table_name IN VARCHAR2,
    p_record_id  IN NUMBER,
    p_action     IN VARCHAR2,
    p_before     IN CLOB,
    p_after      IN CLOB
  ) IS
    v_details CLOB;
  BEGIN
    -- a missing before (insert) or after (delete) is left out of the JSON
    SELECT JSON_OBJECT(
             'before' VALUE p_before FORMAT JSON,
             'after'  VALUE p_after  FORMAT JSON
             ABSENT ON NULL
             RETURNING CLOB)
    INTO v_details
    FROM dual;

    INSERT INTO audit_log (table_name, record_id, action, changed_by, details)
    VALUES (p_table_name, p_record_id, p_action, g_user_id, v_details);
  END log_change;

END plm_audit;
/