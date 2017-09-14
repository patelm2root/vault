#!/bin/bash
set -e

# The tally role will be used by the Tally application to login to the database and perform the
# updates (concepts & indicators) and aggregate queries.
# The adapter role will be used by the EMR Adapter to login to the database and perform the
# transfer of data from the EMR to the Vault.
# Note that the tally/adapter roles are created here rather than in presetup.sql so we can pass
# through the TALLY_PASSWORD and ADAPTER_PASSWORD env variables.
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d postgres <<-EOSQL
  DROP DATABASE IF EXISTS vault;
  CREATE DATABASE vault;

  DROP ROLE IF EXISTS tally;
  CREATE ROLE tally WITH LOGIN ENCRYPTED PASSWORD '$TALLY_PASSWORD';

  DROP ROLE IF EXISTS adapter;
  CREATE ROLE adapter WITH LOGIN ENCRYPTED PASSWORD '$ADAPTER_PASSWORD';

  DROP ROLE IF EXISTS api;
EOSQL

# Drop the default postgres database. This step is debatable as client applications may default
# to connect to this database; however, we control the clients so should not be an issue. And
# then it is just one less object we have to manage.
#psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault <<-EOSQL
#  DROP DATABASE postgres;
#EOSQL

# Run all of the sql scripts in specific order to create the schemas, tables, functions, etc.
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/presetup.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/admin/schema.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/admin/functions/analyze_db.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/admin/functions/verify_key.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/admin/functions/verify_trusted.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/admin/tables/trusted_keys.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/api/schema.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/api/functions/aggregate.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/api/functions/change.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/api/functions/prepare.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/api/functions/reset.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/api/functions/version.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/audit/schema.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/audit/tables/aggregate_log.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/audit/tables/change_log.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/concept/schema.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/indicator/schema.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/universal/schema.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/universal/tables/state.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/universal/tables/clinic.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/universal/tables/practitioner.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/universal/tables/patient.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/universal/tables/patient_practitioner.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/universal/tables/attribute.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/universal/tables/entry.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/universal/tables/entry_attribute.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/universal/data/attributes.sql
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault -f ./sql/postsetup.sql


# Insert the trusted key env variable into the admin.trusted_keys table.
psql -a -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d vault <<-EOSQL
   INSERT INTO admin.trusted_keys (key) VALUES ('$TRUSTED_KEY');
EOSQL
