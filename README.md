# vault
The database for the new HDC endpoint. Includes the universal schema and concept mapping.


## Signing changing

All changes made through the api.change() function must be signed.

Generate a private key. Provide secure passphrase when prompted. Keep this safe!
openssl genrsa -aes256 -out private.pem 4096

Export the public key from the private key. Provide secure passphrase when prompted.
openssl rsa -in private.pem -RSAPublicKey_out -out public.pem

Now that your keys are in place you can use your private key to sign changes.
Note that the first line must be removed when passing this signature to the database function.
For example remove: (RSA-SHA256(data.txt)=)
# File based
openssl dgst -hex -sign private.pem data.txt > signature.txt
# Terminal based
echo "CREATE TABLE concept.code_mapping(concept_key text, code_system text);" | openssl dgst -hex -sign private.pem

## Development

The simplest way of creating the database is through Docker.

`docker run \
 --name vault \
 -e POSTGRES_PASSWORD=postgres_pw \
 -e TALLY_PASSWORD=tally_pw \
 -e ADAPTER_PASSWORD=adapter_pw \
 -e TRUSTED_KEY="$(cat public.pem)" \
 -p5432:5432 \
 hdcbc/vault:develop`
