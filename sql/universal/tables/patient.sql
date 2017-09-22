CREATE TABLE universal.patient
(
  id bigserial NOT NULL,
  clinic_id bigint NOT NULL,
  emr_id text,
  emr_reference text,
  CONSTRAINT patient_pkey PRIMARY KEY (id),
  CONSTRAINT patient_clinic_id_fkey FOREIGN KEY (clinic_id)
    REFERENCES universal.clinic (id) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE UNIQUE INDEX idx_patient_id
  ON universal.patient
  USING btree
  (id);

CREATE INDEX idx_patient_emr_id
  ON universal.patient
  USING btree
  (emr_id COLLATE pg_catalog."default");

ALTER TABLE universal.patient CLUSTER ON idx_patient_emr_id;
