
/*************************************************************************************************/
/* API PERMISSIONS                                                                               */
/*************************************************************************************************/

  --The api role needs the ability to lookup objects within the api, audit, concept, indicator and
  --universal schemas. See below for individual permissions.
  GRANT USAGE ON SCHEMA admin TO api;
  GRANT USAGE ON SCHEMA api TO api;
  GRANT USAGE ON SCHEMA audit TO api;
  GRANT USAGE ON SCHEMA universal TO api;

  --The api role needs the ability to selects rows from the audit.change_log table.
  --This will be used used to determine the last change using the api.version() function.
  GRANT SELECT ON audit.change_log TO api;

  --The api role needs the ability to insert rows into the audit.change_log table.
  --This will be used to create a log entry everytime the api.change() function is called.
  GRANT INSERT ON audit.change_log TO api;
  GRANT USAGE, SELECT ON audit.change_log_id_seq to api;

  --The api role needs the ability to insert rows into the audit.aggregate_log table.
  --This will be used to create an audit log everytime the api.aggregate() function is called.
  GRANT INSERT ON audit.aggregate_log TO api;
  GRANT USAGE, SELECT ON audit.aggregate_log_id_seq to api;

  --The api role needs the ability to execute the admin.analyze_db function.
  --This will be called in the api.prepare() function.
  GRANT EXECUTE ON FUNCTION admin.analyze_db() to api;

  --The api role needs the ability to execute the admin.verify_trusted function.
  --This will be called before a change is applied within the api.change() function
  GRANT EXECUTE ON FUNCTION admin.verify_trusted(text, text) to api;

  --The api role needs the ability to select all data from the universal schema.
  --This will be used within indicator/concept functions to actually query clinical data.
  GRANT SELECT ON ALL TABLES IN SCHEMA universal TO api;

/*************************************************************************************************/
/* TALLY PERMISSIONS                                                                             */
/*************************************************************************************************/
  --The tally role needs the ability to lookup objects within the api schema.
  GRANT USAGE ON SCHEMA api TO tally;

  --The tally role needs the ability to execute all functions within the api schema.
  GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO tally;


/*************************************************************************************************/
/* ADAPTER PERMISSIONS                                                                             */
/*************************************************************************************************/
  --The adapter role needs the ability to create it's own schemas.
  GRANT CREATE ON DATABASE vault to adapter;

  --The adapter role needs the ability to truncate, insert, update, delete etc all data in the
  --universal schema.
  GRANT USAGE ON SCHEMA universal to adapter;

  --The adapter role needs the ability use sequences to generate keys.
  GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA universal TO adapter;

  GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA universal TO adapter;
