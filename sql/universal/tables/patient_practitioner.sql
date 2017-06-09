CREATE TABLE universal.patient_practitioner
(
  id bigserial NOT NULL,
  patient_id bigint NOT NULL,
  practitioner_id bigint NOT NULL,
  emr_id text,
  emr_reference text,
  CONSTRAINT patient_practitioner_pkey PRIMARY KEY (id),
  CONSTRAINT patient_practitioner_patient_id_fkey FOREIGN KEY (patient_id)
      REFERENCES universal.patient (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT patient_practitioner_practitioner_id_fkey FOREIGN KEY (practitioner_id)
    REFERENCES universal.practitioner (id) MATCH SIMPLE
    ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE INDEX idx_patient_practitioner_practitioner_id
  ON universal.patient_practitioner
  USING btree
  (practitioner_id);
