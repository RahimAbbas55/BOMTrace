-- tests for impact_report
-- run as PLM_APP with Run Script, expect only PASS lines, everything is rolled back at the end
SET SERVEROUTPUT ON;

DECLARE
  v_eng NUMBER;
  v     NUMBER;
  v_co  NUMBER;
  v_rc  SYS_REFCURSOR;

  TYPE t_row IS RECORD (
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

  -- one text per report row: changed>affected@levelxquantity, a star marks a top level item
  FUNCTION impact_text(p_co IN NUMBER) RETURN VARCHAR2 IS
    c SYS_REFCURSOR;
    r t_row;
    s VARCHAR2(4000);
  BEGIN
    c := plm_pkg.impact_report(p_co);
    LOOP
      FETCH c INTO r;
      EXIT WHEN c%NOTFOUND;
      s := s || CASE WHEN s IS NULL THEN '' ELSE ' | ' END
             || r.changed_item_number || '>' || NVL(r.affected_item_number, '-')
             || '@' || NVL(TO_CHAR(r.lvl), '-')
             || 'x' || NVL(TO_CHAR(r.total_qty), '-')
             || CASE WHEN r.is_top_level = 'Y' THEN '*' END;
    END LOOP;
    CLOSE c;
    RETURN s;
  END impact_text;

  PROCEDURE report(p_label IN VARCHAR2, p_passed IN BOOLEAN) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN p_passed THEN 'PASS: ' ELSE 'FAIL: ' END || p_label);
  END report;
BEGIN
  SELECT user_id INTO v_eng FROM users WHERE email = 'engineer@bomtrace.dev';

  -- seeded change orders
  report('CO-2026-002 wheel quantity change',
    impact_text(co_id_of('CO-2026-002'))
      = 'EB-1310>EB-1300@1x1 | EB-1310>EB-1000@2x1* | EB-1320>EB-1300@1x1 | EB-1320>EB-1000@2x1*');

  report('CO-2026-004 bearing removal',
    impact_text(co_id_of('CO-2026-004'))
      = 'EB-1110>EB-1100@1x1 | EB-1110>EB-1000@2x1*');

  report('CO-2026-003 two lifecycle changes',
    impact_text(co_id_of('CO-2026-003'))
      = 'EB-1510>EB-1500@1x1 | EB-1510>EB-1000@2x1* | EB-2403>EB-1510@1x1 | EB-2403>EB-1500@2x1 | EB-2403>EB-1000@3x1*');

  -- quantities multiply up the levels, 10 cells per module and 4 modules per pack
  v_co := plm_pkg.create_change_order(v_eng, 'Cell impact');
  v := plm_pkg.add_co_item(v_co, id_of('EB-2301'), 'LIFECYCLE_CHANGE', 'PROTOTYPE');
  report('rolled up quantities of a cell',
    impact_text(v_co) = 'EB-2301>EB-1410@1x10 | EB-2301>EB-1400@2x40 | EB-2301>EB-1000@3x40*');

  -- a part reaching the same assembly by two paths is listed once with the summed quantity
  v_co := plm_pkg.create_change_order(v_eng, 'Spoke impact');
  v := plm_pkg.add_co_item(v_co, id_of('EB-2202'), 'LIFECYCLE_CHANGE', 'PROTOTYPE');
  report('spoke reaches the wheel set by two paths',
    impact_text(v_co) = 'EB-2202>EB-1310@1x36 | EB-2202>EB-1320@1x36 | EB-2202>EB-1300@2x72 | EB-2202>EB-1000@3x72*');

  -- a change on a top level item has nothing above it, but the line still shows
  v_co := plm_pkg.create_change_order(v_eng, 'Top level impact');
  v := plm_pkg.add_co_item(v_co, id_of('EB-1000'), 'LIFECYCLE_CHANGE', 'PROTOTYPE');
  report('top level item has no affected assemblies', impact_text(v_co) = 'EB-1000>-@-x-');

  -- a draft without lines gives an empty report
  v_co := plm_pkg.create_change_order(v_eng, 'Empty draft');
  report('empty change order gives no rows', impact_text(v_co) IS NULL);

  BEGIN
    v_rc := plm_pkg.impact_report(-1);
    report('missing change order rejected', FALSE);
  EXCEPTION WHEN plm_pkg.e_co_not_found THEN report('missing change order rejected', TRUE); END;

  ROLLBACK;
END;
/