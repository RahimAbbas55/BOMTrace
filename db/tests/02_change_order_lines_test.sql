-- tests for create_change_order and add_co_item
-- run as PLM_APP with Run Script, expect only PASS lines, everything is rolled back at the end
SET SERVEROUTPUT ON;

DECLARE
  v_eng   NUMBER;
  v_co    NUMBER;
  v_co3   NUMBER;
  v       NUMBER;

  FUNCTION id_of(p_number IN VARCHAR2) RETURN NUMBER IS
    r NUMBER;
  BEGIN
    SELECT item_id INTO r FROM items WHERE item_number = p_number;
    RETURN r;
  END id_of;

  PROCEDURE report(p_label IN VARCHAR2, p_passed IN BOOLEAN) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN p_passed THEN 'PASS: ' ELSE 'FAIL: ' END || p_label);
  END report;

  FUNCTION stored(p_item IN VARCHAR2, p_type IN VARCHAR2) RETURN VARCHAR2 IS
    r      VARCHAR2(200);
    v_item NUMBER := id_of(p_item);
  BEGIN
    SELECT NVL(old_value, '-') || ' -> ' || NVL(new_value, '-') INTO r
    FROM change_order_items
    WHERE co_id = v_co AND item_id = v_item AND change_type = p_type;
    RETURN r;
  END stored;
BEGIN
  SELECT user_id INTO v_eng FROM users WHERE email = 'engineer@bomtrace.dev';
  SELECT co_id INTO v_co3 FROM change_orders WHERE co_number = 'CO-2026-003';

  v_co := plm_pkg.create_change_order(v_eng, 'Test change order', 'created by the test script');
  report('change order created as DRAFT', v_co IS NOT NULL);

  -- valid lines, old values come from the database
  v := plm_pkg.add_co_item(v_co, id_of('EB-1100'), 'ADD_COMPONENT', '2', id_of('EB-2901'));
  report('add component, stored ' || stored('EB-1100', 'ADD_COMPONENT'), stored('EB-1100', 'ADD_COMPONENT') = '- -> 2');

  v := plm_pkg.add_co_item(v_co, id_of('EB-1310'), 'CHANGE_QTY', '32', id_of('EB-2202'));
  report('change qty, stored ' || stored('EB-1310', 'CHANGE_QTY'), stored('EB-1310', 'CHANGE_QTY') = '36 -> 32');

  v := plm_pkg.add_co_item(v_co, id_of('EB-1110'), 'REMOVE_COMPONENT', NULL, id_of('EB-2013'));
  report('remove component, stored ' || stored('EB-1110', 'REMOVE_COMPONENT'), stored('EB-1110', 'REMOVE_COMPONENT') = '2 -> -');

  v := plm_pkg.add_co_item(v_co, id_of('EB-1510'), 'LIFECYCLE_CHANGE', 'ACTIVE');
  report('lifecycle change, stored ' || stored('EB-1510', 'LIFECYCLE_CHANGE'), stored('EB-1510', 'LIFECYCLE_CHANGE') = 'PROTOTYPE -> ACTIVE');

  -- rejected lines
  BEGIN
    v := plm_pkg.add_co_item(v_co, id_of('EB-2112'), 'ADD_COMPONENT', '1', id_of('EB-1000'));
    report('cycle rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_bom_cycle THEN report('cycle rejected', TRUE); END;

  BEGIN
    v := plm_pkg.add_co_item(v_co, id_of('EB-1000'), 'ADD_COMPONENT', '1', id_of('EB-1100'));
    report('existing line rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_bom_line_exists THEN report('existing line rejected', TRUE); END;

  BEGIN
    v := plm_pkg.add_co_item(v_co, id_of('EB-1100'), 'CHANGE_QTY', '3', id_of('EB-2112'));
    report('change qty on a missing line rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_co_line THEN report('change qty on a missing line rejected', TRUE); END;

  BEGIN
    v := plm_pkg.add_co_item(v_co, id_of('EB-1310'), 'CHANGE_QTY', '30', id_of('EB-2202'));
    report('second line for the same pair rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_co_line THEN report('second line for the same pair rejected', TRUE); END;

  BEGIN
    v := plm_pkg.add_co_item(v_co, id_of('EB-2999'), 'LIFECYCLE_CHANGE', 'ACTIVE');
    report('obsolete item rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_item_obsolete THEN report('obsolete item rejected', TRUE); END;

  BEGIN
    v := plm_pkg.add_co_item(v_co, id_of('EB-1500'), 'ADD_COMPONENT', 'abc', id_of('EB-2902'));
    report('non numeric quantity rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_quantity THEN report('non numeric quantity rejected', TRUE); END;

  BEGIN
    v := plm_pkg.add_co_item(v_co, id_of('EB-1500'), 'SWAP_PART', '1', id_of('EB-2902'));
    report('unknown change type rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_co_line THEN report('unknown change type rejected', TRUE); END;

  BEGIN
    v := plm_pkg.add_co_item(v_co3, id_of('EB-1500'), 'ADD_COMPONENT', '1', id_of('EB-2902'));
    report('line on a SUBMITTED change order rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_transition THEN report('line on a SUBMITTED change order rejected', TRUE); END;

  BEGIN
    v := plm_pkg.add_co_item(-1, id_of('EB-1500'), 'ADD_COMPONENT', '1', id_of('EB-2902'));
    report('missing change order rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_co_not_found THEN report('missing change order rejected', TRUE); END;

  BEGIN
    v := plm_pkg.create_change_order(-1, 'Ghost user');
    report('unknown creator rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_user_not_found THEN report('unknown creator rejected', TRUE); END;

  ROLLBACK;
END;
/