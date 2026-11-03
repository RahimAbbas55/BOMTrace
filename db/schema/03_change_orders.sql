CREATE TABLE change_orders (
  co_id         NUMBER GENERATED ALWAYS AS IDENTITY,
  co_number     VARCHAR2(30)   NOT NULL,
  title         VARCHAR2(200)  NOT NULL,
  description   VARCHAR2(2000),
  status        VARCHAR2(12)   DEFAULT 'DRAFT' NOT NULL,
  created_by    NUMBER         NOT NULL,
  created_at    TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  submitted_at  TIMESTAMP,
  decided_at    TIMESTAMP,
  CONSTRAINT pk_change_orders PRIMARY KEY (co_id),
  CONSTRAINT uq_co_number     UNIQUE (co_number),
  CONSTRAINT ck_co_status     CHECK (status IN ('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED', 'IMPLEMENTED')),
  CONSTRAINT fk_co_creator    FOREIGN KEY (created_by) REFERENCES users (user_id)
);

CREATE INDEX ix_co_created_by ON change_orders (created_by);
CREATE INDEX ix_co_status     ON change_orders (status);

CREATE TABLE change_order_items (
  co_item_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  co_id            NUMBER         NOT NULL,
  item_id          NUMBER         NOT NULL,
  change_type      VARCHAR2(20)   NOT NULL,
  old_value        VARCHAR2(100),
  new_value        VARCHAR2(100),
  related_item_id  NUMBER,
  CONSTRAINT pk_change_order_items PRIMARY KEY (co_item_id),
  CONSTRAINT fk_coi_co      FOREIGN KEY (co_id)           REFERENCES change_orders (co_id) ON DELETE CASCADE,
  CONSTRAINT fk_coi_item    FOREIGN KEY (item_id)         REFERENCES items (item_id),
  CONSTRAINT fk_coi_related FOREIGN KEY (related_item_id) REFERENCES items (item_id),
  CONSTRAINT ck_coi_type    CHECK (change_type IN ('ADD_COMPONENT', 'REMOVE_COMPONENT', 'CHANGE_QTY', 'LIFECYCLE_CHANGE')),
  CONSTRAINT ck_coi_related CHECK (change_type = 'LIFECYCLE_CHANGE' OR related_item_id IS NOT NULL)
);

CREATE INDEX ix_coi_co      ON change_order_items (co_id);
CREATE INDEX ix_coi_item    ON change_order_items (item_id);
CREATE INDEX ix_coi_related ON change_order_items (related_item_id);

CREATE TABLE approvals (
  approval_id  NUMBER GENERATED ALWAYS AS IDENTITY,
  co_id        NUMBER         NOT NULL,
  approver_id  NUMBER         NOT NULL,
  decision     VARCHAR2(10)   NOT NULL,
  comments     VARCHAR2(1000),
  decided_at   TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_approvals      PRIMARY KEY (approval_id),
  CONSTRAINT fk_appr_co        FOREIGN KEY (co_id)       REFERENCES change_orders (co_id),
  CONSTRAINT fk_appr_approver  FOREIGN KEY (approver_id) REFERENCES users (user_id),
  CONSTRAINT ck_appr_decision  CHECK (decision IN ('APPROVED', 'REJECTED')),
  CONSTRAINT uq_appr_co_user   UNIQUE (co_id, approver_id)
);

CREATE INDEX ix_appr_approver ON approvals (approver_id);