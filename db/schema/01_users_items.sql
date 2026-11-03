CREATE TABLE users (
  user_id        NUMBER GENERATED ALWAYS AS IDENTITY,
  email          VARCHAR2(255)  NOT NULL,
  password_hash  VARCHAR2(100)  NOT NULL,
  role           VARCHAR2(10)   NOT NULL,
  created_at     TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_users       PRIMARY KEY (user_id),
  CONSTRAINT uq_users_email UNIQUE (email),
  CONSTRAINT ck_users_role  CHECK (role IN ('ENGINEER', 'APPROVER'))
);

CREATE TABLE items (
  item_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  item_number       VARCHAR2(30)   NOT NULL,
  name              VARCHAR2(200)  NOT NULL,
  description       VARCHAR2(1000),
  item_type         VARCHAR2(10)   NOT NULL,
  lifecycle_status  VARCHAR2(10)   DEFAULT 'PROTOTYPE' NOT NULL,
  uom               VARCHAR2(10)   DEFAULT 'EA' NOT NULL,
  created_by        NUMBER         NOT NULL,
  created_at        TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_items        PRIMARY KEY (item_id),
  CONSTRAINT uq_items_number UNIQUE (item_number),
  CONSTRAINT ck_items_type   CHECK (item_type IN ('MAKE', 'BUY', 'ASSEMBLY')),
  CONSTRAINT ck_items_status CHECK (lifecycle_status IN ('PROTOTYPE', 'ACTIVE', 'OBSOLETE')),
  CONSTRAINT fk_items_creator FOREIGN KEY (created_by) REFERENCES users (user_id)
);

-- oracle does not index foreign keys automatically
CREATE INDEX ix_items_created_by ON items (created_by);