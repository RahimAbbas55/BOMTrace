CREATE TABLE bom_lines (
  bom_line_id     NUMBER GENERATED ALWAYS AS IDENTITY,
  parent_item_id  NUMBER         NOT NULL,
  child_item_id   NUMBER         NOT NULL,
  quantity        NUMBER(12, 4)  NOT NULL,
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_bom_lines         PRIMARY KEY (bom_line_id),
  CONSTRAINT fk_bom_parent        FOREIGN KEY (parent_item_id) REFERENCES items (item_id),
  CONSTRAINT fk_bom_child         FOREIGN KEY (child_item_id)  REFERENCES items (item_id),
  CONSTRAINT uq_bom_parent_child  UNIQUE (parent_item_id, child_item_id),
  CONSTRAINT ck_bom_no_self       CHECK (parent_item_id <> child_item_id),
  CONSTRAINT ck_bom_qty_positive  CHECK (quantity > 0)
);

-- where-used looks up rows by child, the unique key above only helps lookups by parent
CREATE INDEX ix_bom_child ON bom_lines (child_item_id);