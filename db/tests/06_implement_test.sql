-- tests for implement_change_order
-- run as PLM_APP with Run Script, expect only PASS lines, everything is rolled back at the end
SET SERVEROUTPUT ON;

DECLARE
  v_eng NUMBER;
  v_app NUMBER;
  v     NUMBER;
  v_a   NUMBER;
  v_b   NUMBER;
  v_c   NUMBER;
  v_x   NUMBER;
  v_y   NUMBER;
  v_w   NUMBER;
  v_z   NUMBER;
  v_c1  NUMBER;
  v_c2  NUMBER;

  FUNCTION id_of(p_number IN VARCHAR2) RETURN NUMBER IS
    r NUMBER;
  BEGIN
    SELECT item_id INTO r FROM items WHERE item_number = p_number;
    RETURN r;
  END id_of;

  FUNCTION status_of(p_co IN NUMBER) RETURN VARCHAR2 IS
    r VARCHAR2(20);
  BEGIN
    SELECT status INTO r FROM change_orders WHERE co_id = p_co;
    RETURN r;
  END status_of;

  -- current quantity of a BOM line as text, or none when the line does not exist
  FUNCTION qty_of(p_parent IN VARCHAR2, p_child IN VARCHAR2) RETURN VARCHAR2 IS
    r VARCHAR2(30);
  BEGIN
    SELECT RTRIM(TO_CHAR(quantity, 'FM999999990.9999'), '.') INTO r
    FROM bom_lines
    WHERE parent_item_id = id_of(p_parent) AND child_item_id = id_of(p_child);
    RETURN r;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 'none';
  END qty_of;

  FUNCTION lifecycle_of(p_number IN VARCHAR2) RETURN VARCHAR2 IS
    r VARCHAR2(20);
  BEGIN
    SELECT lifecycle_status INTO r FROM items WHERE item_number = p_number;
    RETURN r;
  END lifecycle_of;

  -- submits and approves a change order
  PROCEDURE approve_it(p_co IN NUMBER) IS
  BEGIN
    plm_pkg.submit_change_order(p_co);
    plm_pkg.approve_change_order(p_co, v_app, 'ok');
  END approve_it;

  PROCEDURE report(p_label IN VARCHAR2, p_passed IN BOOLEAN) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN p_passed THEN 'PASS: ' ELSE 'FAIL: ' END || p_label);
  END report;
BEGIN
  SELECT user_id INTO v_eng FROM users WHERE email = 'engineer@bomtrace.dev';
  SELECT user_id INTO v_app FROM users WHERE email = 'approver@bomtrace.dev';

  -- happy path: one line of every type
  v_a := plm_pkg.create_change_order(v_eng, 'Implement test');
  v := plm_pkg.add_co_item(v_a, id_of('EB-1100'), 'ADD_COMPONENT', '2', id_of('EB-2901'));
  v := plm_pkg.add_co_item(v_a, id_of('EB-1310'), 'CHANGE_QTY', '32', id_of('EB-2202'));
  v := plm_pkg.add_co_item(v_a, id_of('EB-1110'), 'REMOVE_COMPONENT', NULL, id_of('EB-2013'));
  v := plm_pkg.add_co_item(v_a, id_of('EB-1510'), 'LIFECYCLE_CHANGE', 'ACTIVE');
  approve_it(v_a);
  plm_pkg.implement_change_order(v_a, v_app);

  report('status is IMPLEMENTED', status_of(v_a) = 'IMPLEMENTED');
  report('component added with quantity 2', qty_of('EB-1100', 'EB-2901') = '2');
  report('quantity changed from 36 to 32', qty_of('EB-1310', 'EB-2202') = '32');
  report('component removed', qty_of('EB-1110', 'EB-2013') = 'none');
  report('lifecycle changed to ACTIVE', lifecycle_of('EB-1510') = 'ACTIVE');

  -- state and role rules
  v_b := plm_pkg.create_change_order(v_eng, 'Only submitted');
  v := plm_pkg.add_co_item(v_b, id_of('EB-1500'), 'ADD_COMPONENT', '1', id_of('EB-2902'));
  plm_pkg.submit_change_order(v_b);
  BEGIN
    plm_pkg.implement_change_order(v_b, v_app);
    report('implement of a SUBMITTED change order rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_transition THEN report('implement of a SUBMITTED change order rejected', TRUE); END;

  v_c := plm_pkg.create_change_order(v_eng, 'Engineer implements');
  v := plm_pkg.add_co_item(v_c, id_of('EB-1600'), 'ADD_COMPONENT', '1', id_of('EB-2902'));
  approve_it(v_c);
  BEGIN
    plm_pkg.implement_change_order(v_c, v_eng);
    report('engineer cannot implement', FALSE);
  EXCEPTION WHEN plm_pkg.e_approver_required THEN report('engineer cannot implement', TRUE); END;
  report('change order is still APPROVED after the refusal', status_of(v_c) = 'APPROVED');

  BEGIN
    plm_pkg.implement_change_order(v_a, v_app);
    report('second implement rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_transition THEN report('second implement rejected', TRUE); END;

  -- atomic: the second change order fails on its ADD line, its CHANGE_QTY line must be undone
  v_x := plm_pkg.create_change_order(v_eng, 'Adds the bolt');
  v := plm_pkg.add_co_item(v_x, id_of('EB-1000'), 'ADD_COMPONENT', '1', id_of('EB-2902'));
  v_y := plm_pkg.create_change_order(v_eng, 'Also adds the bolt');
  v := plm_pkg.add_co_item(v_y, id_of('EB-1320'), 'CHANGE_QTY', '30', id_of('EB-2202'));
  v := plm_pkg.add_co_item(v_y, id_of('EB-1000'), 'ADD_COMPONENT', '3', id_of('EB-2902'));
  approve_it(v_x);
  approve_it(v_y);
  plm_pkg.implement_change_order(v_x, v_app);
  report('first change order applied', qty_of('EB-1000', 'EB-2902') = '1');
  BEGIN
    plm_pkg.implement_change_order(v_y, v_app);
    report('conflicting add rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_bom_line_exists THEN report('conflicting add rejected', TRUE); END;
  report('earlier line was rolled back, quantity is still 36', qty_of('EB-1320', 'EB-2202') = '36');
  report('failed change order is still APPROVED', status_of(v_y) = 'APPROVED');

  -- stale: two change orders drafted from the same quantity, the second one is out of date
  v_w := plm_pkg.create_change_order(v_eng, 'Spokes to 34');
  v := plm_pkg.add_co_item(v_w, id_of('EB-1320'), 'CHANGE_QTY', '34', id_of('EB-2202'));
  v_z := plm_pkg.create_change_order(v_eng, 'Spokes to 32');
  v := plm_pkg.add_co_item(v_z, id_of('EB-1320'), 'CHANGE_QTY', '32', id_of('EB-2202'));
  approve_it(v_w);
  approve_it(v_z);
  plm_pkg.implement_change_order(v_w, v_app);
  BEGIN
    plm_pkg.implement_change_order(v_z, v_app);
    report('stale change rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_co_line THEN report('stale change rejected', TRUE); END;
  report('stale change order is still APPROVED', status_of(v_z) = 'APPROVED');

  -- two change orders that are fine alone but form a loop together
  v_c1 := plm_pkg.create_change_order(v_eng, 'Frame contains drive unit');
  v := plm_pkg.add_co_item(v_c1, id_of('EB-1100'), 'ADD_COMPONENT', '1', id_of('EB-1200'));
  v_c2 := plm_pkg.create_change_order(v_eng, 'Drive unit contains frame');
  v := plm_pkg.add_co_item(v_c2, id_of('EB-1200'), 'ADD_COMPONENT', '1', id_of('EB-1100'));
  approve_it(v_c1);
  approve_it(v_c2);
  plm_pkg.implement_change_order(v_c1, v_app);
  BEGIN
    plm_pkg.implement_change_order(v_c2, v_app);
    report('loop created by two change orders rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_bom_cycle THEN report('loop created by two change orders rejected', TRUE); END;

  ROLLBACK;
END;
/