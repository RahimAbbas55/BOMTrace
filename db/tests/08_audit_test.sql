-- tests for the audit context and the audit triggers
-- run as PLM_APP with Run Script, expect only PASS lines, everything is rolled back at the end
SET SERVEROUTPUT ON;

DECLARE
  v_eng  NUMBER;
  v_item NUMBER;
  v_line NUMBER;
  v_co   NUMBER;
  v      NUMBER;
  a      NUMBER;
  n      NUMBER;
  s      VARCHAR2(4000);

  FUNCTION id_of(p_number IN VARCHAR2) RETURN NUMBER IS
    r NUMBER;
  BEGIN
    SELECT item_id INTO r FROM items WHERE item_number = p_number;
    RETURN r;
  END id_of;

  -- newest audit row for a record and action, null when there is none
  FUNCTION last_audit(p_table IN VARCHAR2, p_record IN NUMBER, p_action IN VARCHAR2) RETURN NUMBER IS
    r NUMBER;
  BEGIN
    SELECT MAX(audit_id) INTO r
    FROM audit_log
    WHERE table_name = p_table AND record_id = p_record AND action = p_action;
    RETURN r;
  END last_audit;

  PROCEDURE report(p_label IN VARCHAR2, p_passed IN BOOLEAN) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN p_passed THEN 'PASS: ' ELSE 'FAIL: ' END || p_label);
  END report;
BEGIN
  SELECT user_id INTO v_eng FROM users WHERE email = 'engineer@bomtrace.dev';

  plm_audit.set_user(v_eng);
  report('get_user returns the acting user', plm_audit.get_user = v_eng);

  -- items: insert, update, delete
  INSERT INTO items (item_number, name, item_type, created_by)
  VALUES ('TEST-9001', 'Audit test item', 'BUY', v_eng)
  RETURNING item_id INTO v_item;

  a := last_audit('ITEMS', v_item, 'INSERT');
  SELECT MAX(changed_by) INTO n FROM audit_log WHERE audit_id = a;
  report('item insert logged with the acting user', a IS NOT NULL AND n = v_eng);

  SELECT MAX(JSON_VALUE(details, '$.after.item_number')) INTO s FROM audit_log WHERE audit_id = a;
  report('item insert has the new values', s = 'TEST-9001');

  UPDATE items SET name = 'Audit test renamed' WHERE item_id = v_item;
  a := last_audit('ITEMS', v_item, 'UPDATE');
  SELECT MAX(JSON_VALUE(details, '$.before.name')) || ' > ' || MAX(JSON_VALUE(details, '$.after.name'))
  INTO s FROM audit_log WHERE audit_id = a;
  report('item update has before and after, ' || s, s = 'Audit test item > Audit test renamed');

  DELETE FROM items WHERE item_id = v_item;
  a := last_audit('ITEMS', v_item, 'DELETE');
  SELECT MAX(JSON_VALUE(details, '$.before.item_number')) INTO s FROM audit_log WHERE audit_id = a;
  report('item delete has the old values', s = 'TEST-9001');

  -- bom lines: insert and delete through the package
  v_line := plm_pkg.add_bom_line(id_of('EB-1100'), id_of('EB-2901'), 2);
  a := last_audit('BOM_LINES', v_line, 'INSERT');
  SELECT MAX(JSON_VALUE(details, '$.after.quantity')) INTO s FROM audit_log WHERE audit_id = a;
  report('bom line insert logged with its quantity', s = '2');

  plm_pkg.remove_bom_line(v_line);
  a := last_audit('BOM_LINES', v_line, 'DELETE');
  report('bom line delete logged', a IS NOT NULL);

  -- change orders: create and submit
  v_co := plm_pkg.create_change_order(v_eng, 'Audit change order');
  a := last_audit('CHANGE_ORDERS', v_co, 'INSERT');
  SELECT MAX(JSON_VALUE(details, '$.after.status')) INTO s FROM audit_log WHERE audit_id = a;
  report('change order insert logged as DRAFT', s = 'DRAFT');

  v := plm_pkg.add_co_item(v_co, id_of('EB-1100'), 'ADD_COMPONENT', '1', id_of('EB-2901'));
  plm_pkg.submit_change_order(v_co);
  a := last_audit('CHANGE_ORDERS', v_co, 'UPDATE');
  SELECT MAX(JSON_VALUE(details, '$.before.status')) || ' > ' || MAX(JSON_VALUE(details, '$.after.status'))
  INTO s FROM audit_log WHERE audit_id = a;
  report('submit logged, ' || s, s = 'DRAFT > SUBMITTED');

  -- without an acting user the change is still logged, with no user
  plm_audit.clear_user;
  UPDATE items SET description = 'changed without a user' WHERE item_number = 'EB-2901';
  a := last_audit('ITEMS', id_of('EB-2901'), 'UPDATE');
  SELECT COUNT(*) INTO n FROM audit_log WHERE audit_id = a AND changed_by IS NULL;
  report('change without a user is logged with no user', n = 1);
  plm_audit.set_user(v_eng);

  -- the audit row belongs to the transaction, a rolled back change leaves no trace
  SAVEPOINT before_rollback_test;
  INSERT INTO items (item_number, name, item_type, created_by)
  VALUES ('TEST-9002', 'Rolled back item', 'BUY', v_eng)
  RETURNING item_id INTO v_item;
  ROLLBACK TO SAVEPOINT before_rollback_test;
  SELECT COUNT(*) INTO n FROM audit_log WHERE table_name = 'ITEMS' AND record_id = v_item;
  report('audit rows are rolled back with the change', n = 0);

  ROLLBACK;
  plm_audit.clear_user;
END;
/