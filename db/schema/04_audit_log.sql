CREATE TABLE audit_log (
  audit_id    NUMBER GENERATED ALWAYS AS IDENTITY,
  table_name  VARCHAR2(30)   NOT NULL,
  record_id   NUMBER         NOT NULL,
  action      VARCHAR2(10)   NOT NULL,
  changed_by  NUMBER,
  changed_at  TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  details     CLOB,
  CONSTRAINT pk_audit_log        PRIMARY KEY (audit_id),
  CONSTRAINT ck_audit_action     CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
  CONSTRAINT ck_audit_details    CHECK (details IS JSON)
);

-- history lookup: all changes to one record, newest first
CREATE INDEX ix_audit_record ON audit_log (table_name, record_id, changed_at);