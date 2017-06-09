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
