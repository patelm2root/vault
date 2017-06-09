/*
 * Used to reset the vault back to version 0. This includes setting the current version to 0 and
 * recreating the concept/indicator schema back to their original state.
 *
 * Note that unlike most other functions in the api schema, this function is owned by the postgres
 * superuser. This is because the the drop/create of schemas requires superuser.

 * Returns void. If an error occurs, a generic warning will be raised.
 */
CREATE OR REPLACE FUNCTION api.reset()
  RETURNS void AS
$BODY$
  DECLARE
    v_start_time timestamp := now();
	BEGIN
    BEGIN
      --Drop all possible persistent changes that the api role could have made,
      --except retain the audit information.
      DROP SCHEMA concept CASCADE;
      CREATE SCHEMA concept AUTHORIZATION api;
      DROP SCHEMA indicator CASCADE;
      CREATE SCHEMA indicator AUTHORIZATION api;

      --Insert a row into audit.change_log reseting to change_id 0
      INSERT INTO audit.change_log(change_id, statement, signature, username, start_time, finish_time, success, error_code, error_message)
      VALUES (0, 'RESET', 'RESET', CURRENT_USER, v_start_time, now(), TRUE, NULL, NULL);

    EXCEPTION WHEN others THEN
      INSERT INTO audit.change_log(change_id, statement, signature, username, start_time, finish_time, success, error_code, error_message)
      VALUES (0, 'RESET', 'RESET', CURRENT_USER, v_start_time, now(), FALSE, SQLSTATE, SQLERRM);

      --Pass generic error information back to the client.
      RAISE WARNING 'Error occured in api.reset(). See audit.change_log.';
    END;
  END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  SECURITY DEFINER;

ALTER FUNCTION api.reset()
  OWNER TO postgres;
