-- tests for approve_change_order and reject_change_order
-- run as PLM_APP with Run Script, expect only PASS lines, everything is rolled back at the end
SET SERVEROUTPUT ON;

DECLARE
  v_eng NUMBER;
  v_app NUMBER;
  v_co  NUMBER;
  v_co2 NUMBER;
  v_co3 NUMBER;
  v_co4 NUMBER;
  v_co5 NUMBER;

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

  FUNCTION decision_of(p_co IN NUMBER) RETURN VARCHAR2 IS
    r VARCHAR2(1100);
  BEGIN
    SELECT decision || ': ' || comments INTO r FROM approvals WHERE co_id = p_co;
    RETURN r;
  END decision_of;

  -- creates a change order with one line and submits it
  FUNCTION submitted_co(p_creator IN NUMBER, p_title IN VARCHAR2) RETURN NUMBER IS
    c NUMBER;
    l NUMBER;
  BEGIN
    c := plm_pkg.create_change_order(p_creator, p_title);
    l := plm_pkg.add_co_item(c, id_of('EB-1100'), 'ADD_COMPONENT', '1', id_of('EB-2901'));
    plm_pkg.submit_change_order(c);
    RETURN c;
  END submitted_co;

  PROCEDURE report(p_label IN VARCHAR2, p_passed IN BOOLEAN) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN p_passed THEN 'PASS: ' ELSE 'FAIL: ' END || p_label);
  END report;
BEGIN
  SELECT user_id INTO v_eng FROM users WHERE email = 'engineer@bomtrace.dev';
  SELECT user_id INTO v_app FROM users WHERE email = 'approver@bomtrace.dev';

  v_co := submitted_co(v_eng, 'Approval test');

  -- who may decide
  BEGIN
    plm_pkg.approve_change_order(v_co, v_eng, 'trying anyway');
    report('engineer cannot approve', FALSE);
  EXCEPTION WHEN plm_pkg.e_approver_required THEN report('engineer cannot approve', TRUE); END;

  BEGIN
    plm_pkg.approve_change_order(v_co, -1, 'ghost');
    report('unknown approver rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_user_not_found THEN report('unknown approver rejected', TRUE); END;

  -- a draft cannot be approved
  v_co2 := plm_pkg.create_change_order(v_eng, 'Still a draft');
  BEGIN
    plm_pkg.approve_change_order(v_co2, v_app, 'too early');
    report('approve of a DRAFT rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_transition THEN report('approve of a DRAFT rejected', TRUE); END;

  -- approval
  plm_pkg.approve_change_order(v_co, v_app, 'Looks good');
  report('status is APPROVED', status_of(v_co) = 'APPROVED');
  DECLARE
    v_ts TIMESTAMP;
  BEGIN
    SELECT decided_at INTO v_ts FROM change_orders WHERE co_id = v_co;
    report('decided_at is set', v_ts IS NOT NULL);
  END;
  report('approval row recorded', decision_of(v_co) = 'APPROVED: Looks good');

  BEGIN
    plm_pkg.approve_change_order(v_co, v_app, 'again');
    report('second approval rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_transition THEN report('second approval rejected', TRUE); END;

  BEGIN
    plm_pkg.reject_change_order(v_co, v_app, 'changed my mind');
    report('reject of an APPROVED change order rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_invalid_transition THEN report('reject of an APPROVED change order rejected', TRUE); END;

  -- rejection needs a comment
  v_co3 := submitted_co(v_eng, 'Rejection test');
  BEGIN
    plm_pkg.reject_change_order(v_co3, v_app, NULL);
    report('reject without a comment rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_comment_required THEN report('reject without a comment rejected', TRUE); END;

  BEGIN
    plm_pkg.reject_change_order(v_co3, v_app, '   ');
    report('reject with a blank comment rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_comment_required THEN report('reject with a blank comment rejected', TRUE); END;

  report('still SUBMITTED after the failed rejections', status_of(v_co3) = 'SUBMITTED');

  plm_pkg.reject_change_order(v_co3, v_app, 'Too risky');
  report('status is REJECTED', status_of(v_co3) = 'REJECTED');
  report('rejection row recorded', decision_of(v_co3) = 'REJECTED: Too risky');

  -- an approver cannot approve their own change order, but can withdraw it
  v_co4 := submitted_co(v_app, 'Approver own change order');
  BEGIN
    plm_pkg.approve_change_order(v_co4, v_app, 'self approval');
    report('self approval rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_self_approval THEN report('self approval rejected', TRUE); END;

  report('still SUBMITTED after the failed self approval', status_of(v_co4) = 'SUBMITTED');

  plm_pkg.reject_change_order(v_co4, v_app, 'Withdrawn by the creator');
  report('creator can reject their own change order', status_of(v_co4) = 'REJECTED');

  BEGIN
    plm_pkg.approve_change_order(-1, v_app, 'ghost');
    report('missing change order rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_co_not_found THEN report('missing change order rejected', TRUE); END;

  -- an item that turned obsolete after submission blocks approval
  v_co5 := submitted_co(v_eng, 'Obsolete at approval');
  UPDATE items SET lifecycle_status = 'OBSOLETE' WHERE item_number = 'EB-2901';
  BEGIN
    plm_pkg.approve_change_order(v_co5, v_app, 'approve anyway');
    report('approval with a newly obsolete item rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_item_obsolete THEN report('approval with a newly obsolete item rejected', TRUE); END;
  report('still SUBMITTED after the blocked approval', status_of(v_co5) = 'SUBMITTED');

  ROLLBACK;
END;
/