DROP SCHEMA IF EXISTS api CASCADE;

CREATE SCHEMA api;

CREATE TABLE api.change
(
  change_id integer NOT NULL,
  statement text,
  update_date timestamp without time zone,
  CONSTRAINT change_pkey PRIMARY KEY (change_id)
);

CREATE OR REPLACE FUNCTION api.perform_update(
    p_change_id integer,
    p_statement text)
  RETURNS void AS
$BODY$
	BEGIN

    --Execute the statement
    EXECUTE p_statement;

    --Update the version table to show that we have performed the update
    INSERT INTO api.change(change_id, statement, update_date) VALUES (p_change_id, p_statement, now());
END;
$BODY$
  LANGUAGE plpgsql VOLATILE;

  CREATE OR REPLACE FUNCTION api.retrieve_version()
    RETURNS integer AS
  $BODY$
  	BEGIN
      RETURN (SELECT MAX(change_id) FROM api.change);
  END;
  $BODY$
    LANGUAGE plpgsql VOLATILE;

    CREATE OR REPLACE FUNCTION api.run_aggregate(
        IN p_indicator text,
        IN p_clinic text,
        IN p_provider text,
        IN p_effective_date date)
      RETURNS TABLE(numerator integer, denominator integer) AS
    $BODY$
    DECLARE
    v_numerator int[];
    v_denominator int[];
    	BEGIN

    EXECUTE format('SELECT * FROM api.%s(p_clinic:=''%s'', p_provider:=''%s'', p_effective_date:=''%s'')', p_indicator, p_clinic, p_provider, p_effective_date)
    INTO v_numerator, v_denominator;

    RETURN QUERY
    SELECT (SELECT array_length(v_numerator, 1)) as numerator,
           (SELECT array_length(v_denominator, 1)) as denominator;

    END;
    $BODY$
      LANGUAGE plpgsql VOLATILE
