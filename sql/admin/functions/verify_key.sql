/*
 * Used to authenticate that the data was signed by someone with access to the private key
 * associated with the specified public key through the use of digital signature.
 *
 * Returns true if valid, otherwise false.
 */
CREATE OR REPLACE FUNCTION admin.verify_key(
  p_data text,
  p_signature text,
  p_publickey text
)
  RETURNS boolean AS
$$
   try:
     import rsa

     pubkey = rsa.PublicKey.load_pkcs1(p_publickey)
     signature = bytearray.fromhex(p_signature)
     verified = rsa.verify(p_data, signature, pubkey)

     return verified
   except:
     return False

$$ LANGUAGE plpythonu VOLATILE
  SECURITY DEFINER;
