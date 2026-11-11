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

  -- creates a DRAFT change order with an auto-generated number, returns co_id
  FUNCTION create_change_order(
    p_created_by  IN NUMBER,
    p_title       IN VARCHAR2,
    p_description IN VARCHAR2 DEFAULT NULL
  ) RETURN NUMBER;

  -- adds one validated change line to a DRAFT change order, returns co_item_id
  -- old_value is recorded from current data, never taken from the caller
  FUNCTION add_co_item(
    p_co_id           IN NUMBER,
    p_item_id         IN NUMBER,
    p_change_type     IN VARCHAR2,
    p_new_value       IN VARCHAR2 DEFAULT NULL,
    p_related_item_id IN NUMBER   DEFAULT NULL
  ) RETURN NUMBER;

  -- DRAFT to SUBMITTED, needs at least one line and no obsolete items
  PROCEDURE submit_change_order(p_co_id IN NUMBER);

  -- SUBMITTED to APPROVED, approver role required, the creator cannot approve their own
  PROCEDURE approve_change_order(
    p_co_id       IN NUMBER,
    p_approver_id IN NUMBER,
    p_comments    IN VARCHAR2 DEFAULT NULL
  );

  -- SUBMITTED to REJECTED, approver role required, a comment is required
  PROCEDURE reject_change_order(
    p_co_id       IN NUMBER,
    p_approver_id IN NUMBER,
    p_comments    IN VARCHAR2
  );

  -- APPROVED to IMPLEMENTED, applies every line to the BOM and items, all or nothing
  PROCEDURE implement_change_order(
    p_co_id   IN NUMBER,
    p_user_id IN NUMBER
  );
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

  PROCEDURE assert_user_exists(p_user_id IN NUMBER) IS
    v_dummy NUMBER;
  BEGIN
    SELECT 1 INTO v_dummy FROM users WHERE user_id = p_user_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20008, 'User not found: ' || p_user_id);
  END assert_user_exists;

  -- rejects parent -> child if the child is the parent or one of its ancestors
  PROCEDURE assert_no_cycle(p_parent_item_id IN NUMBER, p_child_item_id IN NUMBER) IS
    v_hits NUMBER;
  BEGIN
    IF p_parent_item_id = p_child_item_id THEN
      RAISE_APPLICATION_ERROR(-20002,
        'BOM cycle: ' || item_number_of(p_parent_item_id) || ' cannot contain itself');
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
  END assert_no_cycle;

  -- quantity as text without a trailing dot, 0.25 stays 0.25 and 2 becomes 2
  FUNCTION fmt_qty(p_qty IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    RETURN RTRIM(TO_CHAR(p_qty, 'FM999999990.9999'), '.');
  END fmt_qty;

  -- text to a positive number, anything else is an invalid quantity
  FUNCTION parse_qty(p_text IN VARCHAR2) RETURN NUMBER IS
    v_qty NUMBER;
  BEGIN
    IF p_text IS NULL THEN
      RAISE_APPLICATION_ERROR(-20014, 'Quantity is required');
    END IF;
    v_qty := TO_NUMBER(TRIM(p_text));
    IF v_qty <= 0 THEN
      RAISE_APPLICATION_ERROR(-20014, 'Quantity must be greater than zero');
    END IF;
    RETURN v_qty;
  EXCEPTION
    WHEN VALUE_ERROR OR INVALID_NUMBER THEN
      RAISE_APPLICATION_ERROR(-20014, 'Quantity must be a number: ' || p_text);
  END parse_qty;

  -- reads a change order and locks its row until the transaction ends
  FUNCTION lock_change_order(p_co_id IN NUMBER) RETURN change_orders%ROWTYPE IS
    v_row change_orders%ROWTYPE;
  BEGIN
    SELECT * INTO v_row FROM change_orders WHERE co_id = p_co_id FOR UPDATE;
    RETURN v_row;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20005, 'Change order not found: ' || p_co_id);
  END lock_change_order;

  -- the only legal status moves, everything else is rejected
  FUNCTION is_valid_transition(p_from IN VARCHAR2, p_to IN VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    RETURN (p_from = 'DRAFT'     AND p_to = 'SUBMITTED')
        OR (p_from = 'SUBMITTED' AND p_to IN ('APPROVED', 'REJECTED'))
        OR (p_from = 'APPROVED'  AND p_to = 'IMPLEMENTED');
  END is_valid_transition;

  PROCEDURE assert_transition(p_co IN change_orders%ROWTYPE, p_to IN VARCHAR2) IS
  BEGIN
    IF NOT is_valid_transition(p_co.status, p_to) THEN
      RAISE_APPLICATION_ERROR(-20006,
        'Change order ' || p_co.co_number || ' cannot move from ' || p_co.status || ' to ' || p_to);
    END IF;
  END assert_transition;

  -- items can become obsolete after a line was drafted, so check again
  PROCEDURE assert_no_obsolete_lines(p_co_id IN NUMBER, p_co_number IN VARCHAR2) IS
  BEGIN
    FOR r IN (
      SELECT i.item_number
      FROM change_order_items l
      JOIN items i
        ON i.item_id IN (l.item_id,
                         CASE WHEN l.change_type = 'ADD_COMPONENT' THEN l.related_item_id END)
      WHERE l.co_id = p_co_id
        AND i.lifecycle_status = 'OBSOLETE'
      FETCH FIRST 1 ROWS ONLY
    ) LOOP
      RAISE_APPLICATION_ERROR(-20004,
        'Change order ' || p_co_number || ' uses OBSOLETE item ' || r.item_number);
    END LOOP;
  END assert_no_obsolete_lines;

  -- the user must exist and have the APPROVER role
  PROCEDURE assert_approver(p_user_id IN NUMBER) IS
    v_role users.role%TYPE;
  BEGIN
    BEGIN
      SELECT role INTO v_role FROM users WHERE user_id = p_user_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20008, 'User not found: ' || p_user_id);
    END;

    IF v_role <> 'APPROVER' THEN
      RAISE_APPLICATION_ERROR(-20009, 'Only an APPROVER can decide a change order');
    END IF;
  END assert_approver;

  -- writes the approval row and moves the change order to its new status
  PROCEDURE record_decision(
    p_co_id       IN NUMBER,
    p_approver_id IN NUMBER,
    p_decision    IN VARCHAR2,
    p_comments    IN VARCHAR2
  ) IS
  BEGIN
    INSERT INTO approvals (co_id, approver_id, decision, comments)
    VALUES (p_co_id, p_approver_id, p_decision, TRIM(p_comments));

    UPDATE change_orders
    SET status = p_decision,
        decided_at = SYSTIMESTAMP
    WHERE co_id = p_co_id;
  END record_decision;

  -- finds the current BOM line of a change, fails if it no longer matches what was drafted
  PROCEDURE find_current_bom_line(
    p_parent_item_id IN  NUMBER,
    p_child_item_id  IN  NUMBER,
    p_expected_qty   IN  VARCHAR2,
    p_line_id        OUT NUMBER,
    p_qty            OUT NUMBER
  ) IS
  BEGIN
    BEGIN
      SELECT bom_line_id, quantity INTO p_line_id, p_qty
      FROM bom_lines
      WHERE parent_item_id = p_parent_item_id
        AND child_item_id  = p_child_item_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20012,
          'Stale change: ' || item_number_of(p_parent_item_id) ||
          ' no longer contains ' || item_number_of(p_child_item_id));
    END;

    IF fmt_qty(p_qty) <> p_expected_qty THEN
      RAISE_APPLICATION_ERROR(-20012,
        'Stale change: quantity of ' || item_number_of(p_child_item_id) ||
        ' in ' || item_number_of(p_parent_item_id) || ' is now ' || fmt_qty(p_qty) ||
        ' but the change order expects ' || p_expected_qty);
    END IF;
  END find_current_bom_line;

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
    v_id     bom_lines.bom_line_id%TYPE;
  BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
      RAISE_APPLICATION_ERROR(-20014, 'Quantity must be greater than zero');
    END IF;

    assert_item_exists(p_parent_item_id);
    assert_item_exists(p_child_item_id);
    assert_not_obsolete(p_parent_item_id);
    assert_not_obsolete(p_child_item_id);

    SELECT COUNT(*) INTO v_exists
    FROM bom_lines
    WHERE parent_item_id = p_parent_item_id
      AND child_item_id  = p_child_item_id;

    IF v_exists > 0 THEN
      RAISE_APPLICATION_ERROR(-20003,
        item_number_of(p_parent_item_id) || ' already contains ' || item_number_of(p_child_item_id));
    END IF;

    assert_no_cycle(p_parent_item_id, p_child_item_id);

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

  FUNCTION create_change_order(
    p_created_by  IN NUMBER,
    p_title       IN VARCHAR2,
    p_description IN VARCHAR2 DEFAULT NULL
  ) RETURN NUMBER IS
    v_number change_orders.co_number%TYPE;
    v_id     change_orders.co_id%TYPE;
  BEGIN
    assert_user_exists(p_created_by);

    v_number := 'CO-' || TO_CHAR(SYSDATE, 'YYYY') || '-' || LPAD(co_number_seq.NEXTVAL, 3, '0');

    INSERT INTO change_orders (co_number, title, description, status, created_by)
    VALUES (v_number, p_title, p_description, 'DRAFT', p_created_by)
    RETURNING co_id INTO v_id;

    RETURN v_id;
  END create_change_order;

  FUNCTION add_co_item(
    p_co_id           IN NUMBER,
    p_item_id         IN NUMBER,
    p_change_type     IN VARCHAR2,
    p_new_value       IN VARCHAR2 DEFAULT NULL,
    p_related_item_id IN NUMBER   DEFAULT NULL
  ) RETURN NUMBER IS
    v_co       change_orders%ROWTYPE;
    v_type     VARCHAR2(20) := UPPER(TRIM(p_change_type));
    v_old      change_order_items.old_value%TYPE;
    v_new      change_order_items.new_value%TYPE;
    v_qty      NUMBER;
    v_line_qty bom_lines.quantity%TYPE;
    v_count    NUMBER;
    v_id       change_order_items.co_item_id%TYPE;
  BEGIN
    v_co := lock_change_order(p_co_id);

    IF v_co.status <> 'DRAFT' THEN
      RAISE_APPLICATION_ERROR(-20006,
        'Change order ' || v_co.co_number || ' is ' || v_co.status ||
        ', lines can only be added while it is DRAFT');
    END IF;

    assert_item_exists(p_item_id);
    assert_not_obsolete(p_item_id);

    IF v_type IS NULL
       OR v_type NOT IN ('ADD_COMPONENT', 'REMOVE_COMPONENT', 'CHANGE_QTY', 'LIFECYCLE_CHANGE') THEN
      RAISE_APPLICATION_ERROR(-20012, 'Unknown change type: ' || p_change_type);
    END IF;

    IF v_type = 'LIFECYCLE_CHANGE' THEN
      IF p_related_item_id IS NOT NULL THEN
        RAISE_APPLICATION_ERROR(-20012, 'A lifecycle change has no related item');
      END IF;

      v_new := UPPER(TRIM(p_new_value));
      IF v_new IS NULL OR v_new NOT IN ('PROTOTYPE', 'ACTIVE', 'OBSOLETE') THEN
        RAISE_APPLICATION_ERROR(-20012, 'New lifecycle status must be PROTOTYPE, ACTIVE or OBSOLETE');
      END IF;

      SELECT lifecycle_status INTO v_old FROM items WHERE item_id = p_item_id;
      IF v_new = v_old THEN
        RAISE_APPLICATION_ERROR(-20012,
          item_number_of(p_item_id) || ' is already ' || v_old);
      END IF;

    ELSE
      IF p_related_item_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20012, v_type || ' needs a related item');
      END IF;
      assert_item_exists(p_related_item_id);

      IF v_type = 'ADD_COMPONENT' THEN
        -- an obsolete part cannot be added, but it can still be removed or re-quantified
        assert_not_obsolete(p_related_item_id);
        v_qty := parse_qty(p_new_value);

        SELECT COUNT(*) INTO v_count
        FROM bom_lines
        WHERE parent_item_id = p_item_id AND child_item_id = p_related_item_id;
        IF v_count > 0 THEN
          RAISE_APPLICATION_ERROR(-20003,
            item_number_of(p_item_id) || ' already contains ' || item_number_of(p_related_item_id));
        END IF;

        assert_no_cycle(p_item_id, p_related_item_id);
        v_old := NULL;
        v_new := fmt_qty(v_qty);

      ELSE
        -- remove and change quantity both need an existing BOM line
        BEGIN
          SELECT quantity INTO v_line_qty
          FROM bom_lines
          WHERE parent_item_id = p_item_id AND child_item_id = p_related_item_id;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20012,
              item_number_of(p_item_id) || ' does not contain ' || item_number_of(p_related_item_id));
        END;
        v_old := fmt_qty(v_line_qty);

        IF v_type = 'REMOVE_COMPONENT' THEN
          v_new := NULL;
        ELSE
          v_qty := parse_qty(p_new_value);
          IF v_qty = v_line_qty THEN
            RAISE_APPLICATION_ERROR(-20012, 'New quantity equals the current quantity ' || v_old);
          END IF;
          v_new := fmt_qty(v_qty);
        END IF;
      END IF;
    END IF;

    -- one line per item and related item in a change order
    SELECT COUNT(*) INTO v_count
    FROM change_order_items
    WHERE co_id = p_co_id
      AND item_id = p_item_id
      AND (related_item_id = p_related_item_id
           OR (related_item_id IS NULL AND p_related_item_id IS NULL));
    IF v_count > 0 THEN
      RAISE_APPLICATION_ERROR(-20012,
        v_co.co_number || ' already has a line for ' || item_number_of(p_item_id) ||
        CASE WHEN p_related_item_id IS NOT NULL
             THEN ' and ' || item_number_of(p_related_item_id) END);
    END IF;

    INSERT INTO change_order_items (co_id, item_id, change_type, old_value, new_value, related_item_id)
    VALUES (p_co_id, p_item_id, v_type, v_old, v_new, p_related_item_id)
    RETURNING co_item_id INTO v_id;

    RETURN v_id;
  END add_co_item;

  PROCEDURE submit_change_order(p_co_id IN NUMBER) IS
    v_co    change_orders%ROWTYPE;
    v_lines NUMBER;
  BEGIN
    v_co := lock_change_order(p_co_id);
    assert_transition(v_co, 'SUBMITTED');

    SELECT COUNT(*) INTO v_lines FROM change_order_items WHERE co_id = p_co_id;
    IF v_lines = 0 THEN
      RAISE_APPLICATION_ERROR(-20007,
        'Change order ' || v_co.co_number || ' has no lines and cannot be submitted');
    END IF;

    assert_no_obsolete_lines(p_co_id, v_co.co_number);

    UPDATE change_orders
    SET status = 'SUBMITTED',
        submitted_at = SYSTIMESTAMP
    WHERE co_id = p_co_id;
  END submit_change_order;

  PROCEDURE approve_change_order(
    p_co_id       IN NUMBER,
    p_approver_id IN NUMBER,
    p_comments    IN VARCHAR2 DEFAULT NULL
  ) IS
    v_co change_orders%ROWTYPE;
  BEGIN
    v_co := lock_change_order(p_co_id);
    assert_approver(p_approver_id);

    IF v_co.created_by = p_approver_id THEN
      RAISE_APPLICATION_ERROR(-20010,
        'The creator cannot approve their own change order ' || v_co.co_number);
    END IF;

    assert_transition(v_co, 'APPROVED');
    assert_no_obsolete_lines(p_co_id, v_co.co_number);
    record_decision(p_co_id, p_approver_id, 'APPROVED', p_comments);
  END approve_change_order;

  PROCEDURE reject_change_order(
    p_co_id       IN NUMBER,
    p_approver_id IN NUMBER,
    p_comments    IN VARCHAR2
  ) IS
    v_co change_orders%ROWTYPE;
  BEGIN
    v_co := lock_change_order(p_co_id);
    assert_approver(p_approver_id);

    IF TRIM(p_comments) IS NULL THEN
      RAISE_APPLICATION_ERROR(-20011, 'A comment is required to reject a change order');
    END IF;

    assert_transition(v_co, 'REJECTED');
    record_decision(p_co_id, p_approver_id, 'REJECTED', p_comments);
  END reject_change_order;

  PROCEDURE implement_change_order(
    p_co_id   IN NUMBER,
    p_user_id IN NUMBER
  ) IS
    v_co      change_orders%ROWTYPE;
    v_line_id bom_lines.bom_line_id%TYPE;
    v_qty     bom_lines.quantity%TYPE;
    v_new_qty NUMBER;
    v_status  items.lifecycle_status%TYPE;
  BEGIN
    v_co := lock_change_order(p_co_id);
    assert_approver(p_user_id);
    assert_transition(v_co, 'IMPLEMENTED');
    assert_no_obsolete_lines(p_co_id, v_co.co_number);

    -- everything below is all or nothing
    BEGIN
      SAVEPOINT before_implement;

      -- removals first so they can free the way for additions, lifecycle changes last
      FOR r IN (
        SELECT item_id, change_type, old_value, new_value, related_item_id
        FROM change_order_items
        WHERE co_id = p_co_id
        ORDER BY CASE change_type
                   WHEN 'REMOVE_COMPONENT' THEN 1
                   WHEN 'CHANGE_QTY'       THEN 2
                   WHEN 'ADD_COMPONENT'    THEN 3
                   ELSE 4
                 END,
                 co_item_id
      ) LOOP
        IF r.change_type = 'REMOVE_COMPONENT' THEN
          find_current_bom_line(r.item_id, r.related_item_id, r.old_value, v_line_id, v_qty);
          remove_bom_line(v_line_id);

        ELSIF r.change_type = 'CHANGE_QTY' THEN
          find_current_bom_line(r.item_id, r.related_item_id, r.old_value, v_line_id, v_qty);
          v_new_qty := parse_qty(r.new_value);
          UPDATE bom_lines SET quantity = v_new_qty WHERE bom_line_id = v_line_id;

        ELSIF r.change_type = 'ADD_COMPONENT' THEN
          -- full validation again, including the cycle check against the current BOM
          v_line_id := add_bom_line(r.item_id, r.related_item_id, parse_qty(r.new_value));

        ELSE
          SELECT lifecycle_status INTO v_status FROM items WHERE item_id = r.item_id;
          IF v_status <> r.old_value THEN
            RAISE_APPLICATION_ERROR(-20012,
              'Stale change: ' || item_number_of(r.item_id) || ' is now ' || v_status ||
              ' but the change order expects ' || r.old_value);
          END IF;
          UPDATE items SET lifecycle_status = r.new_value WHERE item_id = r.item_id;
        END IF;
      END LOOP;

      UPDATE change_orders SET status = 'IMPLEMENTED' WHERE co_id = p_co_id;
    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK TO SAVEPOINT before_implement;
        RAISE;
    END;
  END implement_change_order;

END plm_pkg;
/