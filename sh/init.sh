#!/bin/bash
set -e

# The tally role will be used by the Tally application to login to the database and perform the
# updates (concepts & indicators) and aggregate queries.
# The adapter role will be used by the EMR Adapter to login to the database and perform the
# transfer of data from the EMR to the Vault.
# Note that the tally/adapter roles are created here rather than in presetup.sql so we can pass
# through the TALLY_PASSWORD and ADAPTER_PASSWORD env variables.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
  CREATE DATABASE vault;
  CREATE ROLE tally WITH LOGIN ENCRYPTED PASSWORD '$TALLY_PASSWORD';
  CREATE ROLE adapter WITH LOGIN ENCRYPTED PASSWORD '$ADAPTER_PASSWORD';
EOSQL

# Drop the default postgres database. This step is debatable as client applications may default
# to connect to this database; however, we control the clients so should not be an issue. And
# then it is just one less object we have to manage.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault <<-EOSQL
  DROP DATABASE postgres;
EOSQL

# Run all of the sql scripts in specific order to create the schemas, tables, functions, etc.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault \
 -f ./sql/presetup.sql \
 -f ./sql/admin/schema.sql \
 -f ./sql/admin/functions/analyze_db.sql \
 -f ./sql/admin/functions/verify_key.sql \
 -f ./sql/admin/functions/verify_trusted.sql \
 -f ./sql/admin/tables/trusted_keys.sql \
 -f ./sql/api/schema.sql \
 -f ./sql/api/functions/aggregate.sql \
 -f ./sql/api/functions/change.sql \
 -f ./sql/api/functions/prepare.sql \
 -f ./sql/api/functions/reset.sql \
 -f ./sql/api/functions/version.sql \
 -f ./sql/audit/schema.sql \
 -f ./sql/audit/tables/aggregate_log.sql \
 -f ./sql/audit/tables/change_log.sql \
 -f ./sql/concept/schema.sql \
 -f ./sql/indicator/schema.sql \
 -f ./sql/universal/schema.sql \
 -f ./sql/universal/tables/state.sql \
 -f ./sql/universal/tables/clinic.sql \
 -f ./sql/universal/tables/practitioner.sql \
 -f ./sql/universal/tables/patient.sql \
 -f ./sql/universal/tables/patient_practitioner.sql \
 -f ./sql/universal/tables/attribute.sql \
 -f ./sql/universal/tables/entry.sql \
 -f ./sql/universal/tables/entry_attribute.sql \
 -f ./sql/universal/data/attributes.sql \
 -f ./sql/postsetup.sql;

# Insert the trusted key env variable into the admin.trusted_keys table.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault <<-EOSQL
   INSERT INTO admin.trusted_keys (key) VALUES ('$TRUSTED_KEY');
EOSQL
