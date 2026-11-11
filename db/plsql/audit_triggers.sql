-- row level audit triggers, they write to AUDIT_LOG through plm_audit.log_change
-- run after plm_audit.sql, and again after db/schema/99_reset.sql

CREATE OR REPLACE TRIGGER trg_items_audit
AFTER INSERT OR UPDATE OR DELETE ON items
FOR EACH ROW
DECLARE
  v_before CLOB;
  v_after  CLOB;
BEGIN
  IF INSERTING OR UPDATING THEN
    SELECT JSON_OBJECT(
             'item_number'      VALUE :NEW.item_number,
             'name'             VALUE :NEW.name,
             'description'      VALUE :NEW.description,
             'item_type'        VALUE :NEW.item_type,
             'lifecycle_status' VALUE :NEW.lifecycle_status,
             'uom'              VALUE :NEW.uom
             RETURNING CLOB)
    INTO v_after FROM dual;
  END IF;

  IF UPDATING OR DELETING THEN
    SELECT JSON_OBJECT(
             'item_number'      VALUE :OLD.item_number,
             'name'             VALUE :OLD.name,
             'description'      VALUE :OLD.description,
             'item_type'        VALUE :OLD.item_type,
             'lifecycle_status' VALUE :OLD.lifecycle_status,
             'uom'              VALUE :OLD.uom
             RETURNING CLOB)
    INTO v_before FROM dual;
  END IF;

  plm_audit.log_change(
    'ITEMS',
    COALESCE(:NEW.item_id, :OLD.item_id),
    CASE WHEN INSERTING THEN 'INSERT' WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END,
    v_before,
    v_after);
END trg_items_audit;
/

CREATE OR REPLACE TRIGGER trg_bom_lines_audit
AFTER INSERT OR UPDATE OR DELETE ON bom_lines
FOR EACH ROW
DECLARE
  v_before CLOB;
  v_after  CLOB;
BEGIN
  IF INSERTING OR UPDATING THEN
    SELECT JSON_OBJECT(
             'parent_item_id' VALUE :NEW.parent_item_id,
             'child_item_id'  VALUE :NEW.child_item_id,
             'quantity'       VALUE :NEW.quantity
             RETURNING CLOB)
    INTO v_after FROM dual;
  END IF;

  IF UPDATING OR DELETING THEN
    SELECT JSON_OBJECT(
             'parent_item_id' VALUE :OLD.parent_item_id,
             'child_item_id'  VALUE :OLD.child_item_id,
             'quantity'       VALUE :OLD.quantity
             RETURNING CLOB)
    INTO v_before FROM dual;
  END IF;

  plm_audit.log_change(
    'BOM_LINES',
    COALESCE(:NEW.bom_line_id, :OLD.bom_line_id),
    CASE WHEN INSERTING THEN 'INSERT' WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END,
    v_before,
    v_after);
END trg_bom_lines_audit;
/

CREATE OR REPLACE TRIGGER trg_change_orders_audit
AFTER INSERT OR UPDATE OR DELETE ON change_orders
FOR EACH ROW
DECLARE
  v_before CLOB;
  v_after  CLOB;
BEGIN
  IF INSERTING OR UPDATING THEN
    SELECT JSON_OBJECT(
             'co_number'    VALUE :NEW.co_number,
             'title'        VALUE :NEW.title,
             'description'  VALUE :NEW.description,
             'status'       VALUE :NEW.status,
             'created_by'   VALUE :NEW.created_by,
             'submitted_at' VALUE :NEW.submitted_at,
             'decided_at'   VALUE :NEW.decided_at
             RETURNING CLOB)
    INTO v_after FROM dual;
  END IF;

  IF UPDATING OR DELETING THEN
    SELECT JSON_OBJECT(
             'co_number'    VALUE :OLD.co_number,
             'title'        VALUE :OLD.title,
             'description'  VALUE :OLD.description,
             'status'       VALUE :OLD.status,
             'created_by'   VALUE :OLD.created_by,
             'submitted_at' VALUE :OLD.submitted_at,
             'decided_at'   VALUE :OLD.decided_at
             RETURNING CLOB)
    INTO v_before FROM dual;
  END IF;

  plm_audit.log_change(
    'CHANGE_ORDERS',
    COALESCE(:NEW.co_id, :OLD.co_id),
    CASE WHEN INSERTING THEN 'INSERT' WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END,
    v_before,
    v_after);
END trg_change_orders_audit;
/