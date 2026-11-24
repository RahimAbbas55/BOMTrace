-- tests for add_bom_line and remove_bom_line
-- run as PLM_APP with Run Script, expect only PASS lines, everything is rolled back at the end
SET SERVEROUTPUT ON;

DECLARE
  v_id NUMBER;

  FUNCTION id_of(p_number IN VARCHAR2) RETURN NUMBER IS
    v NUMBER;
  BEGIN
    SELECT item_id INTO v FROM items WHERE item_number = p_number;
    RETURN v;
  END id_of;
BEGIN
  -- the bike is an ancestor of the MOSFET, so MOSFET -> bike is a cycle
  BEGIN
    v_id := plm_pkg.add_bom_line(id_of('EB-2112'), id_of('EB-1000'), 1);
    DBMS_OUTPUT.PUT_LINE('FAIL: cycle was not rejected');
  EXCEPTION
    WHEN plm_pkg.e_bom_cycle THEN DBMS_OUTPUT.PUT_LINE('PASS: ' || SQLERRM);
  END;

  BEGIN
    v_id := plm_pkg.add_bom_line(id_of('EB-2901'), id_of('EB-2901'), 1);
    DBMS_OUTPUT.PUT_LINE('FAIL: self reference was not rejected');
  EXCEPTION
    WHEN plm_pkg.e_bom_cycle THEN DBMS_OUTPUT.PUT_LINE('PASS: ' || SQLERRM);
  END;

  BEGIN
    v_id := plm_pkg.add_bom_line(id_of('EB-1000'), id_of('EB-1100'), 1);
    DBMS_OUTPUT.PUT_LINE('FAIL: duplicate was not rejected');
  EXCEPTION
    WHEN plm_pkg.e_bom_line_exists THEN DBMS_OUTPUT.PUT_LINE('PASS: ' || SQLERRM);
  END;

  BEGIN
    v_id := plm_pkg.add_bom_line(id_of('EB-1220'), id_of('EB-2999'), 1);
    DBMS_OUTPUT.PUT_LINE('FAIL: obsolete item was not rejected');
  EXCEPTION
    WHEN plm_pkg.e_item_obsolete THEN DBMS_OUTPUT.PUT_LINE('PASS: ' || SQLERRM);
  END;

  BEGIN
    v_id := plm_pkg.add_bom_line(id_of('EB-1100'), id_of('EB-2901'), 0);
    DBMS_OUTPUT.PUT_LINE('FAIL: zero quantity was not rejected');
  EXCEPTION
    WHEN plm_pkg.e_invalid_quantity THEN DBMS_OUTPUT.PUT_LINE('PASS: ' || SQLERRM);
  END;

  -- happy path: add a valid line, then remove it again
  v_id := plm_pkg.add_bom_line(id_of('EB-1100'), id_of('EB-2901'), 2);
  DBMS_OUTPUT.PUT_LINE('PASS: added line ' || v_id);
  plm_pkg.remove_bom_line(v_id);
  DBMS_OUTPUT.PUT_LINE('PASS: removed line ' || v_id);

  BEGIN
    plm_pkg.remove_bom_line(-1);
    DBMS_OUTPUT.PUT_LINE('FAIL: missing line was not reported');
  EXCEPTION
    WHEN plm_pkg.e_bom_line_not_found THEN DBMS_OUTPUT.PUT_LINE('PASS: ' || SQLERRM);
  END;

  ROLLBACK;
END;
/