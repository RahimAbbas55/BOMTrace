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

END plm_pkg;
/