CREATE TABLE audit.change_log
(
  id bigserial NOT NULL PRIMARY KEY,
  change_id bigint,
  statement text,
  signature text,
  username text not null,
  start_time timestamp without time zone NOT NULL,
  finish_time timestamp without time zone NOT NULL,
  success boolean NOT NULL,
  error_code text,
  error_message text
);
