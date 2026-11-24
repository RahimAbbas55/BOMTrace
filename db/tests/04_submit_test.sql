-- tests for submit_change_order and the status transition check
-- run as PLM_APP with Run Script, expect only PASS lines, everything is rolled back at the end
SET SERVEROUTPUT ON;

DECLARE
  v_eng NUMBER;
  v_co  NUMBER;
  v     NUMBER;

  FUNCTION id_of(p_number IN VARCHAR2) RETURN NUMBER IS
    r NUMBER;
  BEGIN
    SELECT item_id INTO r FROM items WHERE item_number = p_number;
    RETURN r;
  END id_of;

  FUNCTION co_id_of(p_number IN VARCHAR2) RETURN NUMBER IS
    r NUMBER;
  BEGIN
    SELECT co_id INTO r FROM change_orders WHERE co_number = p_number;
    RETURN r;
  END co_id_of;

  FUNCTION status_of(p_co IN NUMBER) RETURN VARCHAR2 IS
    r VARCHAR2(20);
  BEGIN
    SELECT status INTO r FROM change_orders WHERE co_id = p_co;
    RETURN r;
  END status_of;

  PROCEDURE report(p_label IN VARCHAR2, p_passed IN BOOLEAN) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN p_passed THEN 'PASS: ' ELSE 'FAIL: ' END || p_label);
  END report;
BEGIN
  SELECT user_id INTO v_eng FROM users WHERE email = 'engineer@bomtrace.dev';

  -- a draft with no lines cannot be submitted
  v_co := plm_pkg.create_change_order(v_eng, 'Submit test');
  BEGIN
    plm_pkg.submit_change_order(v_co);
    report('empty change order rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_co_empty THEN report('empty change order rejected', TRUE); END;

  -- with a line it can be submitted
  v := plm_pkg.add_co_item(v_co, id_of('EB-1100'), 'ADD_COMPONENT', '2', id_of('EB-2901'));
  plm_pkg.submit_change_order(v_co);
  report('status is SUBMITTED after submit', status_of(v_co) = 'SUBMITTED');

  DECLARE
    v_ts TIMESTAMP;
  BEGIN
    SELECT submitted_at INTO v_ts FROM change_orders WHERE co_id = v_co;
    report('submitted_at is set', v_ts IS NOT NULL);
  END;

  -- illegal moves
  BEGIN
    plm_pkg.submit_change_order(v_co);
    report('second submit rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_transition THEN report('second submit rejected', TRUE); END;

  BEGIN
    plm_pkg.submit_change_order(co_id_of('CO-2026-002'));
    report('submit of an APPROVED change order rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_transition THEN report('submit of an APPROVED change order rejected', TRUE); END;

  BEGIN
    plm_pkg.submit_change_order(co_id_of('CO-2026-001'));
    report('submit of an IMPLEMENTED change order rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_transition THEN report('submit of an IMPLEMENTED change order rejected', TRUE); END;

  BEGIN
    plm_pkg.submit_change_order(co_id_of('CO-2026-004'));
    report('submit of a REJECTED change order rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_transition THEN report('submit of a REJECTED change order rejected', TRUE); END;

  BEGIN
    plm_pkg.submit_change_order(-1);
    report('missing change order rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_co_not_found THEN report('missing change order rejected', TRUE); END;

  -- an item that turned obsolete after the line was drafted
  v_co := plm_pkg.create_change_order(v_eng, 'Obsolete recheck');
  v := plm_pkg.add_co_item(v_co, id_of('EB-1100'), 'ADD_COMPONENT', '1', id_of('EB-2901'));
  UPDATE items SET lifecycle_status = 'OBSOLETE' WHERE item_number = 'EB-2901';
  BEGIN
    plm_pkg.submit_change_order(v_co);
    report('line with a newly obsolete item rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_item_obsolete THEN report('line with a newly obsolete item rejected', TRUE); END;
  report('change order is still DRAFT after the rejection', status_of(v_co) = 'DRAFT');

  ROLLBACK;
END;
/