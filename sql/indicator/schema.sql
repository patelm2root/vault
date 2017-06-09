/*
 * The indicator schema will contain a function for every indicator.
 *
 * The functions will be executed using the api.aggregate function. Each indicator function must
 * have a common structure (see api.aggregate()).
 *
 * This schema will initially contain zero indicator functions. Once Tally is executed for the first
 * time it will call api.change() to insert the indicator functions.
 */
CREATE SCHEMA indicator AUTHORIZATION api;
