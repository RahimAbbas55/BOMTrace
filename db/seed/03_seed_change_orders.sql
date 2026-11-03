DECLARE
  v_engineer users.user_id%TYPE;
  v_approver users.user_id%TYPE;
  v_co       change_orders.co_id%TYPE;

  -- creates a change order header, timestamps are given as "days ago"
  FUNCTION add_co(
    p_number         IN VARCHAR2,
    p_title          IN VARCHAR2,
    p_desc           IN VARCHAR2,
    p_status         IN VARCHAR2,
    p_created_ago    IN NUMBER,
    p_submitted_ago  IN NUMBER DEFAULT NULL,
    p_decided_ago    IN NUMBER DEFAULT NULL
  ) RETURN change_orders.co_id%TYPE IS
    v_id change_orders.co_id%TYPE;
  BEGIN
    INSERT INTO change_orders
      (co_number, title, description, status, created_by, created_at, submitted_at, decided_at)
    VALUES
      (p_number, p_title, p_desc, p_status, v_engineer,
       SYSTIMESTAMP - NUMTODSINTERVAL(p_created_ago, 'DAY'),
       SYSTIMESTAMP - NUMTODSINTERVAL(p_submitted_ago, 'DAY'),
       SYSTIMESTAMP - NUMTODSINTERVAL(p_decided_ago, 'DAY'))
    RETURNING co_id INTO v_id;
    RETURN v_id;
  END add_co;

  -- adds one change line, items are given by item number
  PROCEDURE add_co_item(
    p_co       IN NUMBER,
    p_item     IN VARCHAR2,
    p_type     IN VARCHAR2,
    p_old      IN VARCHAR2,
    p_new      IN VARCHAR2,
    p_related  IN VARCHAR2 DEFAULT NULL
  ) IS
  BEGIN
    INSERT INTO change_order_items
      (co_id, item_id, change_type, old_value, new_value, related_item_id)
    VALUES
      (p_co,
       (SELECT item_id FROM items WHERE item_number = p_item),
       p_type, p_old, p_new,
       (SELECT item_id FROM items WHERE item_number = p_related));
  END add_co_item;

  PROCEDURE add_approval(
    p_co        IN NUMBER,
    p_decision  IN VARCHAR2,
    p_comments  IN VARCHAR2,
    p_ago       IN NUMBER
  ) IS
  BEGIN
    INSERT INTO approvals (co_id, approver_id, decision, comments, decided_at)
    VALUES (p_co, v_approver, p_decision, p_comments,
            SYSTIMESTAMP - NUMTODSINTERVAL(p_ago, 'DAY'));
  END add_approval;
BEGIN
  SELECT user_id INTO v_engineer FROM users WHERE email = 'engineer@bomtrace.dev';
  SELECT user_id INTO v_approver FROM users WHERE email = 'approver@bomtrace.dev';

  -- 1. IMPLEMENTED: already reflected in the seeded BOM and item data
  v_co := add_co('CO-2026-001', 'Replace legacy controller PCB',
                 'Legacy board is discontinued, switch to the new PCB blank.',
                 'IMPLEMENTED', 20, 19, 18);
  add_co_item(v_co, 'EB-2999', 'LIFECYCLE_CHANGE', 'ACTIVE', 'OBSOLETE');
  add_co_item(v_co, 'EB-1220', 'ADD_COMPONENT', NULL, '1', 'EB-2111');
  add_approval(v_co, 'APPROVED', 'Supplier confirmed end of life. New board has the same footprint.', 18);

  -- 2. APPROVED: ready to be implemented in the demo
  v_co := add_co('CO-2026-002', 'Lighter wheels: reduce spoke count',
                 'Cut spokes from 36 to 32 on both wheels to save weight.',
                 'APPROVED', 8, 7, 5);
  add_co_item(v_co, 'EB-1310', 'CHANGE_QTY', '36', '32', 'EB-2202');
  add_co_item(v_co, 'EB-1320', 'CHANGE_QTY', '36', '32', 'EB-2202');
  add_approval(v_co, 'APPROVED', 'Fatigue test report supports the lower spoke count.', 5);

  -- 3. SUBMITTED: waiting for an approver
  v_co := add_co('CO-2026-003', 'Release display unit to production',
                 'Display unit and its PCB passed validation and can leave prototype status.',
                 'SUBMITTED', 3, 2);
  add_co_item(v_co, 'EB-1510', 'LIFECYCLE_CHANGE', 'PROTOTYPE', 'ACTIVE');
  add_co_item(v_co, 'EB-2403', 'LIFECYCLE_CHANGE', 'PROTOTYPE', 'ACTIVE');

  -- 4. REJECTED: shows the approval comment
  v_co := add_co('CO-2026-004', 'Remove headset bearings from fork',
                 'Proposal to drop the two headset bearings to cut cost.',
                 'REJECTED', 12, 11, 10);
  add_co_item(v_co, 'EB-1110', 'REMOVE_COMPONENT', '2', NULL, 'EB-2013');
  add_approval(v_co, 'REJECTED', 'Bearings are required for steering. Resubmit with a cheaper bearing spec.', 10);

  -- 5. DRAFT: still being edited by the engineer
  v_co := add_co('CO-2026-005', 'Increase battery capacity',
                 'Add a fifth cell module to extend range.',
                 'DRAFT', 1);
  add_co_item(v_co, 'EB-1400', 'CHANGE_QTY', '4', '5', 'EB-1410');

  COMMIT;
END;
/