-- tests for create_item and update_item
-- run as PLM_APP with Run Script, expect only PASS lines, everything is rolled back at the end
SET SERVEROUTPUT ON;

DECLARE
  v_eng  NUMBER;
  v_item NUMBER;
  v      NUMBER;

  FUNCTION id_of(p_number IN VARCHAR2) RETURN NUMBER IS
    r NUMBER;
  BEGIN
    SELECT item_id INTO r FROM items WHERE item_number = p_number;
    RETURN r;
  END id_of;

  -- number, status, unit, name and description of an item as one text
  FUNCTION show_item(p_item IN NUMBER) RETURN VARCHAR2 IS
    r VARCHAR2(1000);
  BEGIN
    SELECT item_number || '/' || lifecycle_status || '/' || uom || '/' || name || '/' || NVL(description, '-')
    INTO r FROM items WHERE item_id = p_item;
    RETURN r;
  END show_item;

  PROCEDURE report(p_label IN VARCHAR2, p_passed IN BOOLEAN) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN p_passed THEN 'PASS: ' ELSE 'FAIL: ' END || p_label);
  END report;
BEGIN
  SELECT user_id INTO v_eng FROM users WHERE email = 'engineer@bomtrace.dev';

  -- create: number in upper case, PROTOTYPE, default unit
  v_item := plm_pkg.create_item(v_eng, ' test-1001 ', '  Test widget  ', 'buy');
  report('item created, ' || show_item(v_item),
         show_item(v_item) = 'TEST-1001/PROTOTYPE/EA/Test widget/-');

  BEGIN
    v := plm_pkg.create_item(v_eng, 'Test-1001', 'Same number again', 'BUY');
    report('duplicate item number rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_item_exists THEN report('duplicate item number rejected', TRUE); END;

  BEGIN
    v := plm_pkg.create_item(-1, 'TEST-1002', 'Ghost creator', 'BUY');
    report('unknown creator rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_user_not_found THEN report('unknown creator rejected', TRUE); END;

  BEGIN
    v := plm_pkg.create_item(v_eng, 'TEST-1003', 'Bad type', 'GADGET');
    report('invalid item type rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_item THEN report('invalid item type rejected', TRUE); END;

  BEGIN
    v := plm_pkg.create_item(v_eng, 'TEST-1004', '   ', 'BUY');
    report('blank name rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_item THEN report('blank name rejected', TRUE); END;

  BEGIN
    v := plm_pkg.create_item(v_eng, '   ', 'No number', 'BUY');
    report('blank item number rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_item THEN report('blank item number rejected', TRUE); END;

  -- update: all fields, then only one field
  plm_pkg.update_item(v_item, 'Renamed widget', 'A better description', 'kg');
  report('all fields updated, ' || show_item(v_item),
         show_item(v_item) = 'TEST-1001/PROTOTYPE/KG/Renamed widget/A better description');

  plm_pkg.update_item(v_item, p_description => 'Only the description changed');
  report('a partial update keeps the other fields, ' || show_item(v_item),
         show_item(v_item) = 'TEST-1001/PROTOTYPE/KG/Renamed widget/Only the description changed');

  -- rules
  BEGIN
    plm_pkg.update_item(id_of('EB-2999'), 'Cannot rename');
    report('obsolete item cannot be edited', FALSE);
  EXCEPTION WHEN plm_pkg.e_item_obsolete THEN report('obsolete item cannot be edited', TRUE); END;

  BEGIN
    plm_pkg.update_item(-1, 'Nobody');
    report('missing item rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_item_not_found THEN report('missing item rejected', TRUE); END;

  BEGIN
    plm_pkg.update_item(v_item);
    report('update with nothing to change rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_item THEN report('update with nothing to change rejected', TRUE); END;

  BEGIN
    plm_pkg.update_item(v_item, '   ');
    report('blank name on update rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_item THEN report('blank name on update rejected', TRUE); END;

  report('lifecycle status was never touched by an update',
         show_item(v_item) LIKE 'TEST-1001/PROTOTYPE/%');

  ROLLBACK;
END;
/