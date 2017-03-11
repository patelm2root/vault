\connect vault
DROP SCHEMA IF EXISTS api CASCADE;  
DROP FUNCTION IF EXISTS api.perform_update(p_change_id,p_statement) CASCADE; CREATE OR REPLACE FUNCTION api.perform_update(p_change_id integer, p_statement text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
	BEGIN

    --Execute the statement
    EXECUTE p_statement;

    --Update the version table to show that we have performed the update
    INSERT INTO api.change(change_id, statement, update_date) VALUES (p_change_id, p_statement, now());
END;
$function$
;
DROP FUNCTION IF EXISTS api.retrieve_version() CASCADE; CREATE OR REPLACE FUNCTION api.retrieve_version()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
  	BEGIN
      RETURN (SELECT MAX(change_id) FROM api.change);
  END;
  $function$
;
DROP FUNCTION IF EXISTS api.run_aggregate(p_indicator,p_clinic,p_provider,p_effective_date,numerator,denominator) CASCADE; CREATE OR REPLACE FUNCTION api.run_aggregate(p_indicator text, p_clinic text, p_provider text, p_effective_date date)
 RETURNS TABLE(numerator integer, denominator integer)
 LANGUAGE plpgsql
AS $function$
    DECLARE
    v_numerator int[];
    v_denominator int[];

    BEGIN

		EXECUTE format('SELECT * FROM indicator.%s(p_clinic_reference:=''%s''::text, p_practitioner_msp:=''%s''::text, p_effective_date:=''%s''::date)', p_indicator, p_clinic, p_provider, p_effective_date)
		INTO v_numerator, v_denominator;

		RETURN QUERY
		SELECT (SELECT COALESCE(array_length(v_numerator, 1), 0)) as numerator,
			   (SELECT COALESCE(array_length(v_denominator, 1), 0)) as denominator;

    END;
    $function$
;
