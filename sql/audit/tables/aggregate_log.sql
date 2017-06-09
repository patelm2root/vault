CREATE TABLE audit.aggregate_log
(
  id bigserial NOT NULL PRIMARY KEY,
  indicator text,
  clinic text,
  provider text,
  effective_date text,
  username text not null,
  start_time timestamp without time zone not null,
  finish_time timestamp without time zone not null,
  success boolean not null,
  numerator integer,
  denominator integer,
  error_code text,
  error_message text
);
