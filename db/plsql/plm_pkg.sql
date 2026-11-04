CREATE OR REPLACE PACKAGE plm_pkg AS
  -- error codes raised by this package, see docs/error-codes.md for HTTP mapping
  e_item_not_found      EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_item_not_found,      -20001);
  e_bom_cycle           EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_bom_cycle,           -20002);
  e_bom_line_exists     EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_bom_line_exists,     -20003);
  e_item_obsolete       EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_item_obsolete,       -20004);
  e_co_not_found        EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_co_not_found,        -20005);
  e_invalid_transition  EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_invalid_transition,  -20006);
  e_co_empty            EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_co_empty,            -20007);
  e_user_not_found      EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_user_not_found,      -20008);
  e_approver_required   EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_approver_required,   -20009);
  e_self_approval       EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_self_approval,       -20010);
  e_comment_required    EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_comment_required,    -20011);
  e_invalid_co_line     EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_invalid_co_line,     -20012);
  e_bom_line_not_found  EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_bom_line_not_found,  -20013);
  e_invalid_quantity    EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_invalid_quantity,    -20014);

  -- full multi-level BOM of an item, depth first, with rolled-up quantities
  FUNCTION explode_bom(p_item_id IN NUMBER) RETURN SYS_REFCURSOR;

  -- every assembly, at any level, that contains the item
  FUNCTION where_used(p_item_id IN NUMBER) RETURN SYS_REFCURSOR;

  -- adds a component to an assembly, rejects cycles, returns the new bom_line_id
  FUNCTION add_bom_line(
    p_parent_item_id IN NUMBER,
    p_child_item_id  IN NUMBER,
    p_quantity       IN NUMBER
  ) RETURN NUMBER;

  -- removes a component from an assembly
  PROCEDURE remove_bom_line(p_bom_line_id IN NUMBER);
END plm_pkg;
/

CREATE OR REPLACE PACKAGE BODY plm_pkg AS

  PROCEDURE assert_item_exists(p_item_id IN NUMBER) IS
    v_dummy NUMBER;
  BEGIN
    SELECT 1 INTO v_dummy FROM items WHERE item_id = p_item_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20001, 'Item not found: ' || p_item_id);
  END assert_item_exists;

  FUNCTION item_number_of(p_item_id IN NUMBER) RETURN VARCHAR2 IS
    v_number items.item_number%TYPE;
  BEGIN
    SELECT item_number INTO v_number FROM items WHERE item_id = p_item_id;
    RETURN v_number;
  END item_number_of;

  PROCEDURE assert_not_obsolete(p_item_id IN NUMBER) IS
    v_status items.lifecycle_status%TYPE;
  BEGIN
    SELECT lifecycle_status INTO v_status FROM items WHERE item_id = p_item_id;
    IF v_status = 'OBSOLETE' THEN
      RAISE_APPLICATION_ERROR(-20004,
        'Item ' || item_number_of(p_item_id) || ' is OBSOLETE and cannot be changed or used');
    END IF;
  END assert_not_obsolete;

  FUNCTION explode_bom(p_item_id IN NUMBER) RETURN SYS_REFCURSOR IS
    v_cur SYS_REFCURSOR;
  BEGIN
    assert_item_exists(p_item_id);

    OPEN v_cur FOR
      WITH bom_tree (item_id, item_number, parent_item_id, lvl, qty_per_parent, rolled_qty) AS (
        SELECT b.child_item_id, c.item_number, b.parent_item_id,
               1, CAST(b.quantity AS NUMBER), CAST(b.quantity AS NUMBER)
        FROM bom_lines b
        JOIN items c ON c.item_id = b.child_item_id
        WHERE b.parent_item_id = p_item_id
        UNION ALL
        SELECT b.child_item_id, c.item_number, b.parent_item_id,
               t.lvl + 1, b.quantity, t.rolled_qty * b.quantity
        FROM bom_tree t
        JOIN bom_lines b ON b.parent_item_id = t.item_id
        JOIN items c ON c.item_id = b.child_item_id
      )
      SEARCH DEPTH FIRST BY item_number SET order_seq
      CYCLE item_id SET is_cycle TO 'Y' DEFAULT 'N'
      SELECT t.lvl,
             i.item_id,
             i.item_number,
             i.name,
             i.item_type,
             i.lifecycle_status,
             i.uom,
             t.parent_item_id,
             t.qty_per_parent,
             t.rolled_qty
      FROM bom_tree t
      JOIN items i ON i.item_id = t.item_id
      WHERE t.is_cycle = 'N'
      ORDER BY t.order_seq;

    RETURN v_cur;
  END explode_bom;

  FUNCTION where_used(p_item_id IN NUMBER) RETURN SYS_REFCURSOR IS
    v_cur SYS_REFCURSOR;
  BEGIN
    assert_item_exists(p_item_id);

    OPEN v_cur FOR
      WITH used_in (parent_item_id, lvl, rolled_qty) AS (
        SELECT b.parent_item_id, 1, CAST(b.quantity AS NUMBER)
        FROM bom_lines b
        WHERE b.child_item_id = p_item_id
        UNION ALL
        SELECT b.parent_item_id, u.lvl + 1, u.rolled_qty * b.quantity
        FROM used_in u
        JOIN bom_lines b ON b.child_item_id = u.parent_item_id
      )
      CYCLE parent_item_id SET is_cycle TO 'Y' DEFAULT 'N'
      SELECT i.item_id,
             i.item_number,
             i.name,
             i.item_type,
             i.lifecycle_status,
             MIN(u.lvl)        AS lvl,
             SUM(u.rolled_qty) AS total_qty
      FROM used_in u
      JOIN items i ON i.item_id = u.parent_item_id
      WHERE u.is_cycle = 'N'
      GROUP BY i.item_id, i.item_number, i.name, i.item_type, i.lifecycle_status
      ORDER BY MIN(u.lvl), i.item_number;

    RETURN v_cur;
  END where_used;

  FUNCTION add_bom_line(
    p_parent_item_id IN NUMBER,
    p_child_item_id  IN NUMBER,
    p_quantity       IN NUMBER
  ) RETURN NUMBER IS
    v_exists NUMBER;
    v_hits   NUMBER;
    v_id     bom_lines.bom_line_id%TYPE;
  BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
      RAISE_APPLICATION_ERROR(-20014, 'Quantity must be greater than zero');
    END IF;

    assert_item_exists(p_parent_item_id);
    assert_item_exists(p_child_item_id);
    assert_not_obsolete(p_parent_item_id);
    assert_not_obsolete(p_child_item_id);

    IF p_parent_item_id = p_child_item_id THEN
      RAISE_APPLICATION_ERROR(-20002,
        'BOM cycle: ' || item_number_of(p_parent_item_id) || ' cannot contain itself');
    END IF;

    SELECT COUNT(*) INTO v_exists
    FROM bom_lines
    WHERE parent_item_id = p_parent_item_id
      AND child_item_id  = p_child_item_id;

    IF v_exists > 0 THEN
      RAISE_APPLICATION_ERROR(-20003,
        item_number_of(p_parent_item_id) || ' already contains ' || item_number_of(p_child_item_id));
    END IF;

    -- walk upward from the parent, is the new child one of its ancestors?
    SELECT COUNT(*) INTO v_hits
    FROM bom_lines
    WHERE parent_item_id = p_child_item_id
    START WITH child_item_id = p_parent_item_id
    CONNECT BY NOCYCLE PRIOR parent_item_id = child_item_id;

    IF v_hits > 0 THEN
      RAISE_APPLICATION_ERROR(-20002,
        'BOM cycle: ' || item_number_of(p_child_item_id) ||
        ' already contains ' || item_number_of(p_parent_item_id));
    END IF;

    INSERT INTO bom_lines (parent_item_id, child_item_id, quantity)
    VALUES (p_parent_item_id, p_child_item_id, p_quantity)
    RETURNING bom_line_id INTO v_id;

    RETURN v_id;
  END add_bom_line;

  PROCEDURE remove_bom_line(p_bom_line_id IN NUMBER) IS
    v_parent bom_lines.parent_item_id%TYPE;
  BEGIN
    BEGIN
      SELECT parent_item_id INTO v_parent
      FROM bom_lines
      WHERE bom_line_id = p_bom_line_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20013, 'BOM line not found: ' || p_bom_line_id);
    END;

    assert_not_obsolete(v_parent);

    DELETE FROM bom_lines WHERE bom_line_id = p_bom_line_id;
  END remove_bom_line;

END plm_pkg;
/