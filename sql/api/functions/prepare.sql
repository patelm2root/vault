/*
 * Used to prepares the database for calls to the api.aggregate() function. Preparation is done by
 * analyzing indexes and calling the concept.prepare() function if it exists. The concept.prepare()
 * is intended to refresh any materialized views that have been created in the concept schema.
 *
 * Returns true on success or false on error.
 */
CREATE OR REPLACE FUNCTION api.prepare()
  RETURNS boolean AS
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

        --Return true to indicate that the preparation succeeded.
        RETURN TRUE;
      END IF;
    EXCEPTION WHEN others THEN
      --Return false to indicate that the preparation failed.
      RETURN FALSE;
    END;
  END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  SECURITY DEFINER;

ALTER FUNCTION api.prepare()
  OWNER TO api;
