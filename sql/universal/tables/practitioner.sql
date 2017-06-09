CREATE TABLE universal.practitioner
(
  id bigserial NOT NULL,
  clinic_id bigint NOT NULL,
  name text,
  identifier text NOT NULL,
  identifier_type text NOT NULL,
  emr_id text,
  emr_reference text,
  CONSTRAINT practitioner_pkey PRIMARY KEY (id)
);

CREATE INDEX idx_practitioner_identifier_type_id
  ON universal.practitioner
  USING btree
  (identifier_type COLLATE pg_catalog."default", id);
