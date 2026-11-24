-- end to end test: item, change order, impact, submit, approve, implement, BOM and audit trail
-- run as PLM_APP with Run Script, expect only PASS lines, everything is rolled back at the end
SET SERVEROUTPUT ON;

DECLARE
  v_eng  NUMBER;
  v_app  NUMBER;
  v_item NUMBER;
  v_co   NUMBER;
  v_line NUMBER;
  v_caliper NUMBER;
  v_pads NUMBER;
  v      NUMBER;
  n      NUMBER;
  s      VARCHAR2(4000);
  a      NUMBER;

  TYPE t_impact IS RECORD (
    co_item_id           NUMBER,
    change_type          VARCHAR2(20),
    changed_item_number  VARCHAR2(30),
    changed_item_name    VARCHAR2(200),
    related_item_number  VARCHAR2(30),
    old_value            VARCHAR2(100),
    new_value            VARCHAR2(100),
    affected_item_id     NUMBER,
    affected_item_number VARCHAR2(30),
    affected_name        VARCHAR2(200),
    affected_type        VARCHAR2(10),
    affected_status      VARCHAR2(10),
    lvl                  NUMBER,
    total_qty            NUMBER,
    is_top_level         VARCHAR2(1)
  );

  TYPE t_bom IS RECORD (
    lvl              NUMBER,
    item_id          NUMBER,
    item_number      VARCHAR2(30),
    name             VARCHAR2(200),
    item_type        VARCHAR2(10),
    lifecycle_status VARCHAR2(10),
    uom              VARCHAR2(10),
    parent_item_id   NUMBER,
    qty_per_parent   NUMBER,
    rolled_qty       NUMBER
  );

  TYPE t_used IS RECORD (
    item_id          NUMBER,
    item_number      VARCHAR2(30),
    name             VARCHAR2(200),
    item_type        VARCHAR2(10),
    lifecycle_status VARCHAR2(10),
    lvl              NUMBER,
    total_qty        NUMBER
  );

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

  FUNCTION lifecycle_of(p_number IN VARCHAR2) RETURN VARCHAR2 IS
    r VARCHAR2(20);
  BEGIN
    SELECT lifecycle_status INTO r FROM items WHERE item_number = p_number;
    RETURN r;
  END lifecycle_of;

  FUNCTION qty_of(p_parent IN VARCHAR2, p_child IN VARCHAR2) RETURN VARCHAR2 IS
    r        VARCHAR2(30);
    v_parent NUMBER := id_of(p_parent);
    v_child  NUMBER := id_of(p_child);
  BEGIN
    SELECT RTRIM(TO_CHAR(quantity, 'FM999999990.9999'), '.') INTO r
    FROM bom_lines
    WHERE parent_item_id = v_parent AND child_item_id = v_child;
    RETURN r;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 'none';
  END qty_of;

  FUNCTION impact_text(p_co IN NUMBER) RETURN VARCHAR2 IS
    c SYS_REFCURSOR;
    r t_impact;
    t VARCHAR2(4000);
  BEGIN
    c := plm_pkg.impact_report(p_co);
    LOOP
      FETCH c INTO r;
      EXIT WHEN c%NOTFOUND;
      t := t || CASE WHEN t IS NULL THEN '' ELSE ' | ' END
             || r.changed_item_number || '>' || NVL(r.affected_item_number, '-')
             || '@' || NVL(TO_CHAR(r.lvl), '-')
             || 'x' || NVL(TO_CHAR(r.total_qty), '-')
             || CASE WHEN r.is_top_level = 'Y' THEN '*' END;
    END LOOP;
    CLOSE c;
    RETURN t;
  END impact_text;

  -- total quantity of a part in one finished bike, summed over every place it appears
  FUNCTION rolled_in_bike(p_number IN VARCHAR2) RETURN NUMBER IS
    c SYS_REFCURSOR;
    r t_bom;
    t NUMBER := 0;
  BEGIN
    c := plm_pkg.explode_bom(id_of('EB-1000'));
    LOOP
      FETCH c INTO r;
      EXIT WHEN c%NOTFOUND;
      IF r.item_number = p_number THEN
        t := t + r.rolled_qty;
      END IF;
    END LOOP;
    CLOSE c;
    RETURN t;
  END rolled_in_bike;

  FUNCTION where_used_text(p_number IN VARCHAR2) RETURN VARCHAR2 IS
    c SYS_REFCURSOR;
    r t_used;
    t VARCHAR2(4000);
  BEGIN
    c := plm_pkg.where_used(id_of(p_number));
    LOOP
      FETCH c INTO r;
      EXIT WHEN c%NOTFOUND;
      t := t || CASE WHEN t IS NULL THEN '' ELSE ' | ' END
             || r.item_number || '@' || r.lvl || 'x' || r.total_qty;
    END LOOP;
    CLOSE c;
    RETURN t;
  END where_used_text;

  PROCEDURE report(p_label IN VARCHAR2, p_passed IN BOOLEAN) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN p_passed THEN 'PASS: ' ELSE 'FAIL: ' END || p_label);
  END report;
BEGIN
  SELECT user_id INTO v_eng FROM users WHERE email = 'engineer@bomtrace.dev';
  SELECT user_id INTO v_app FROM users WHERE email = 'approver@bomtrace.dev';

  -- the engineer creates a new part and a change order that adds it to the brake caliper
  plm_audit.set_user(v_eng);

  v_item := plm_pkg.create_item(v_eng, 'EB-3001', 'Brake Rotor', 'BUY', 'Vented disc rotor');
  report('new part starts as PROTOTYPE', lifecycle_of('EB-3001') = 'PROTOTYPE');

  v_co := plm_pkg.create_change_order(v_eng, 'Brake upgrade', 'Add a rotor and use more pads');
  v := plm_pkg.add_co_item(v_co, id_of('EB-1610'), 'ADD_COMPONENT', '1', id_of('EB-3001'));
  v := plm_pkg.add_co_item(v_co, id_of('EB-1610'), 'CHANGE_QTY', '4', id_of('EB-2502'));
  v := plm_pkg.add_co_item(v_co, id_of('EB-3001'), 'LIFECYCLE_CHANGE', 'ACTIVE');

  report('impact report shows the brake system and the bike',
    impact_text(v_co) =
      'EB-1610>EB-1600@1x2 | EB-1610>EB-1000@2x2* | EB-1610>EB-1600@1x2 | EB-1610>EB-1000@2x2* | EB-3001>-@-x-');

  plm_pkg.submit_change_order(v_co);
  report('change order is SUBMITTED', status_of(v_co) = 'SUBMITTED');

  -- the approver decides and implements
  plm_audit.set_user(v_app);

  plm_pkg.approve_change_order(v_co, v_app, 'Rotor passed the brake test');
  report('change order is APPROVED', status_of(v_co) = 'APPROVED');
  SELECT MAX(decision || ': ' || comments) INTO s FROM approvals WHERE co_id = v_co;
  report('approval recorded with its comment', s = 'APPROVED: Rotor passed the brake test');

  plm_pkg.implement_change_order(v_co, v_app);
  report('change order is IMPLEMENTED', status_of(v_co) = 'IMPLEMENTED');

  -- the product structure changed
  report('pad quantity is now 4', qty_of('EB-1610', 'EB-2502') = '4');
  report('rotor is in the caliper', qty_of('EB-1610', 'EB-3001') = '1');
  report('rotor is now ACTIVE', lifecycle_of('EB-3001') = 'ACTIVE');
  report('a bike needs 2 rotors (one per caliper)', rolled_in_bike('EB-3001') = 2);
  report('a bike needs 8 pads (4 per caliper)', rolled_in_bike('EB-2502') = 8);
  report('where used of the rotor climbs to the bike',
    where_used_text('EB-3001') = 'EB-1610@1x1 | EB-1600@2x2 | EB-1000@3x2');

  -- the audit trail
  SELECT COUNT(*) INTO n FROM audit_log WHERE table_name = 'CHANGE_ORDERS' AND record_id = v_co;
  report('change order has 4 audit rows (create, submit, approve, implement)', n = 4);

  SELECT MIN(audit_id) INTO a FROM audit_log
  WHERE table_name = 'CHANGE_ORDERS' AND record_id = v_co AND action = 'UPDATE';
  SELECT COUNT(*) INTO n FROM audit_log WHERE audit_id = a AND changed_by = v_eng;
  report('the submit is attributed to the engineer', n = 1);

  SELECT MAX(audit_id) INTO a FROM audit_log
  WHERE table_name = 'CHANGE_ORDERS' AND record_id = v_co AND action = 'UPDATE';
  SELECT COUNT(*) INTO n FROM audit_log
  WHERE audit_id = a AND changed_by = v_app AND JSON_VALUE(details, '$.after.status') = 'IMPLEMENTED';
  report('the implementation is attributed to the approver', n = 1);

  v_caliper := id_of('EB-1610');
  v_pads    := id_of('EB-2502');
  SELECT bom_line_id INTO v_line FROM bom_lines
  WHERE parent_item_id = v_caliper AND child_item_id = v_pads;
  SELECT MAX(audit_id) INTO a FROM audit_log
  WHERE table_name = 'BOM_LINES' AND record_id = v_line AND action = 'UPDATE';
  SELECT MAX(JSON_VALUE(details, '$.before.quantity')) || ' > ' || MAX(JSON_VALUE(details, '$.after.quantity'))
  INTO s FROM audit_log WHERE audit_id = a;
  report('the pad quantity change is logged, ' || s, s = '2 > 4');

  SELECT MAX(audit_id) INTO a FROM audit_log
  WHERE table_name = 'ITEMS' AND record_id = v_item AND action = 'UPDATE';
  SELECT MAX(JSON_VALUE(details, '$.before.lifecycle_status')) || ' > ' || MAX(JSON_VALUE(details, '$.after.lifecycle_status'))
  INTO s FROM audit_log WHERE audit_id = a;
  report('the rotor lifecycle change is logged, ' || s, s = 'PROTOTYPE > ACTIVE');

  ROLLBACK;
  plm_audit.clear_user;
END;
/