CREATE TABLE universal.entry
(
  id bigserial NOT NULL,
  patient_id bigint NOT NULL,
  emr_table text NOT NULL,
  emr_id text,
  emr_reference text,
  CONSTRAINT entry_pkey PRIMARY KEY (id),
  CONSTRAINT entry_patient_id_fkey FOREIGN KEY (patient_id)
    REFERENCES universal.patient (id) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE INDEX idx_entry_emr_table_emr_id_id
  ON universal.entry
  USING btree
  (emr_table COLLATE pg_catalog."default", emr_id COLLATE pg_catalog."default", id);

CREATE INDEX idx_entry_emr_id
  ON universal.entry
  USING btree
  (emr_id COLLATE pg_catalog."default");

ALTER TABLE universal.entry CLUSTER ON idx_entry_emr_id;
