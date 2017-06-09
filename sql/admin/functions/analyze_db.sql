/*
 * Used to force an analyze on the entire database.
 *
 * Returns void.
 */
CREATE OR REPLACE FUNCTION admin.analyze_db()
  RETURNS void AS
$BODY$
	BEGIN
    ANALYZE;
  END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  SECURITY DEFINER;
