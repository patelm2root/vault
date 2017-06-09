/*
 * Used to prepares the database for calls to the api.aggregate() function. Preparation is done by
 * analyzing indexes and calling the concept.prepare() function if it exists. The concept.prepare()
 * is intended to refresh any materialized views that have been created in the concept schema.
 *
 * Returns void. If an error occurs, a generic warning will be raised.
 */
CREATE OR REPLACE FUNCTION api.prepare()
  RETURNS void AS
$BODY$
	BEGIN
    BEGIN
      EXECUTE admin.analyze_db();

      --If the concept.prepare() function exists then execute it.
      IF(EXISTS(SELECT 1
                  FROM pg_proc as f
                  JOIN pg_namespace as s
                    ON s.oid = f.pronamespace
                 WHERE f.proname = 'prepare'
                   AND s.nspname = 'concept' )) THEN
        EXECUTE concept.prepare();
      END IF;
    EXCEPTION WHEN others THEN
      --Pass generic error information back to the client.
      RAISE WARNING 'Error occured in api.prepare(). See server log.';
    END;
  END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  SECURITY DEFINER;

ALTER FUNCTION api.prepare()
  OWNER TO api;
