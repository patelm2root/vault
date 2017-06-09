ALTER DEFAULT PRIVILEGES REVOKE ALL ON FUNCTIONS FROM public;

--Drop the public schema completely, it will not be used.
DROP SCHEMA public CASCADE;

--Note that this is an untrusted language.
--Only superusers can create functions in untrusted languages.
CREATE EXTENSION plpythonu;

--The api role will be the owner of the majority of the functions within the api schema. Each of
--these functions will be executed with "security definer" meaning the functions will run using the
--privileges of the api role.
CREATE ROLE api;
