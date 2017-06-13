/*
 * Used to run an indicator against the universal schema and retrieve an aggregate
 * numerator and denominator.
 *
 * p_indicator: The indicator to run. This is required and must match the name of a function
 * within the indicator schema that will be executed.
 *
 * p_clinic: The clinic to retrieve indicator results for. This is required and should match
 * a value within the universal.clinic.hdc_reference column.
 *
 * p_provider: The provider to retrieve indicator results for. This is optional. If provided
 * it should match a value within the universal.practitioner.identifier column. If ommitted,
 * the indicator will be run at the clinic level.
 *
 * p_effective_date: The date to run the indicator as of. This is required.
 *
 * Returns a pair of integers (numerator and denominator) on success. If an error occurs, then
 * 0 rows are returned.
 *
 * Regardless of success or failure, a row will be inserted into the audit.aggregate_log table.
 */
CREATE OR REPLACE FUNCTION api.aggregate(
  IN p_indicator text,
  IN p_clinic text,
  IN p_provider text,
  IN p_effective_date date
)
  RETURNS TABLE(numerator integer, denominator integer) AS
$BODY$
  DECLARE
    v_start_time timestamp := now();
    v_numerator_array int[];
    v_denominator_array int[];
    v_numerator int;
    v_denominator int;
  BEGIN
    BEGIN
      --Simple prevention of SQL injection through p_indicator parameter.
      IF(p_indicator !~ '^[a-zA-Z0-9_]*$') THEN
          RAISE EXCEPTION 'Parameter p_indicator can only contains alphanumeric and underscore';
      END IF;

      --Further whitelist p_indicator to be a function that actually exists in the indicator schema.
      IF(NOT EXISTS(SELECT 1
                      FROM pg_proc as f
                      JOIN pg_namespace as s
                        ON s.oid = f.pronamespace
                     WHERE f.proname = p_indicator
                       AND s.nspname = 'indicator' )) THEN
          RAISE EXCEPTION 'Indicator function % does not exist', p_indicator;
      END IF;

      --Execute the indicator function and store the array results returned.
      --Note possibility of SQL Injection through p_indicator here.
      EXECUTE format('SELECT * FROM indicator.%s(p_clinic_reference:=$1, p_practitioner_msp:=$2, p_effective_date:=$3)', p_indicator)
      INTO v_numerator_array, v_denominator_array
      USING p_clinic, p_provider, p_effective_date;

      --Count the items in each array returned from indicator function.
      v_numerator = array_length(v_numerator_array, 1);
      v_denominator = array_length(v_denominator_array, 1);

      --Insert a row into the aggregate_log table to indicate that the aggregate query was executed successfully.
      INSERT INTO audit.aggregate_log(indicator, clinic, provider, effective_date, username, start_time, finish_time, success, numerator, denominator, error_code, error_message)
      VALUES (p_indicator, p_clinic, p_provider, p_effective_date, CURRENT_USER, v_start_time, now(), TRUE, v_numerator, v_denominator, NULL, NULL);

      --Return the aggregate data.
      RETURN QUERY SELECT v_numerator as numerator, v_denominator as denominator;

    EXCEPTION WHEN others THEN
      --Insert a row into the aggregate_log table to indicate that the query failed to execute.
      INSERT INTO audit.aggregate_log(indicator, clinic, provider, effective_date, username, start_time, finish_time, success, numerator, denominator, error_code, error_message)
      VALUES (p_indicator, p_clinic, p_provider, p_effective_date, CURRENT_USER, v_start_time, now(), FALSE, NULL, NULL, SQLSTATE, SQLERRM);

      --Pass generic error information back to the client.
      RAISE WARNING 'Error occured in api.aggregate(). See audit.aggregate_log.';
    END;
  END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  SECURITY DEFINER;

ALTER FUNCTION api.aggregate(text, text, text, date)
  OWNER TO api;
