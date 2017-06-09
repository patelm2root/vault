/*
 * Used to determine the current version of the vault. The current version is the change_id of the
 * last change that was applied through api.change() that was successfully applied. If there have
 * been no changed made then the current version is 0.
 *
 * Returns the current version. If an error occurs, a generic warning will be raised.
 */
CREATE OR REPLACE FUNCTION api.version()
  RETURNS bigint AS
$BODY$
  DECLARE
    v_last_change_id bigint;
  BEGIN
    BEGIN
      SELECT change_id
      INTO v_last_change_id
      FROM audit.change_log
      WHERE success IS TRUE
      ORDER BY id DESC
      LIMIT 1;

      RETURN COALESCE(v_last_change_id, 0);
    EXCEPTION WHEN others THEN
      --Pass generic error information back to the client.
      RAISE WARNING 'Error occured in api.version(). See server log.';
    END;
  END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  SECURITY DEFINER;

ALTER FUNCTION api.version()
  OWNER TO api;
