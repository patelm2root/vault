CREATE TABLE universal.entry_attribute
(
  id bigserial NOT NULL,
  entry_id bigint NOT NULL,
  attribute_id numeric(6,3) NOT NULL,
  code_system text,
  code_value text,
  text_value text,
  date_value date,
  boolean_value boolean,
  numeric_value numeric(18,6),
  emr_id text,
  emr_reference text,
  emr_effective_date timestamp with time zone NOT NULL,
  hdc_effective_date timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT entry_attribute_pkey PRIMARY KEY (id),
  CONSTRAINT entry_attribute_attribute_id_fkey FOREIGN KEY (attribute_id)
    REFERENCES universal.attribute (id) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT entry_attribute_entry_id_fkey FOREIGN KEY (entry_id)
    REFERENCES universal.entry (id) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE INDEX idx_entry_attribute_attribute_id
  ON universal.entry_attribute
  USING btree
  (attribute_id);

CREATE INDEX idx_entry_attribute_code_system
  ON universal.entry_attribute
  USING btree
  (lower(code_system) COLLATE pg_catalog."default");

CREATE INDEX idx_entry_attribute_code_value
  ON universal.entry_attribute
  USING btree
  (code_value COLLATE pg_catalog."default");

CREATE INDEX idx_entry_attribute_date_value
  ON universal.entry_attribute
  USING btree
  (date_value);

CREATE INDEX idx_entry_attribute_entry_id
  ON universal.entry_attribute
  USING btree
  (entry_id);

CREATE INDEX idx_entry_attribute_text_value
  ON universal.entry_attribute
  USING btree
  (text_value COLLATE pg_catalog."default");
