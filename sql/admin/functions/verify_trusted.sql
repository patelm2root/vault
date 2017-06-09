/*
 * Used to authenticate that the data was signed with on of the keys specified in api.trusted_keys.
 *
 * Returns true if valid, otherwise false.
 */
CREATE OR REPLACE FUNCTION admin.verify_trusted(
  p_data text,
  p_signature text
)
  RETURNS boolean AS
$BODY$
	BEGIN
      RETURN (
        EXISTS(SELECT 1
                 FROM admin.trusted_keys as t
                WHERE admin.verify_key(p_data, p_signature, t.key) IS TRUE)
      );
  END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  SECURITY DEFINER;
