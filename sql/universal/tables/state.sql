CREATE TABLE universal.state
(
  id bigserial NOT NULL,
  record_type text NOT NULL,
  record_id bigint NOT NULL,
  state text DEFAULT 'active'::text,
  effective_date timestamp with time zone,
  emr_id text,
  emr_reference text,
  CONSTRAINT state_pkey PRIMARY KEY (id)
);

CREATE INDEX idx_state_record_type_effective_date
  ON universal.state
  USING btree
  (record_type COLLATE pg_catalog."default", effective_date DESC);

CREATE INDEX idx_state_state
  ON universal.state
  USING btree
  (state COLLATE pg_catalog."default");
