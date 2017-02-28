DROP SCHEMA IF EXISTS universal CASCADE;

CREATE SCHEMA universal;

CREATE TABLE universal.clinic
(
    id BIGSERIAL NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    hdc_reference TEXT NOT NULL,

    emr_id TEXT,
    emr_reference TEXT
);

CREATE TABLE universal.practitioner
(
    id BIGSERIAL NOT NULL PRIMARY KEY,
    clinic_id BIGINT NOT NULL,
    name TEXT,
    identifier TEXT NOT NULL,
    identifier_type TEXT NOT NULL,

    emr_id TEXT,
    emr_reference TEXT
);

CREATE TABLE universal.patient
(
    id BIGSERIAL NOT NULL PRIMARY KEY,
    clinic_id BIGINT NOT NULL REFERENCES universal.clinic(id),

    emr_id TEXT,
    emr_reference TEXT
);

CREATE TABLE universal.patient_practitioner
(
    id BIGSERIAL NOT NULL PRIMARY KEY,
    patient_id BIGINT NOT NULL REFERENCES universal.patient(id),
    practitioner_id BIGINT NOT NULL REFERENCES universal.practitioner(id),

    emr_id TEXT,
    emr_reference TEXT
);

CREATE TABLE universal.entry
(
    id BIGSERIAL NOT NULL PRIMARY KEY,
    patient_id BIGINT NOT NULL REFERENCES universal.patient(id),

    emr_table TEXT NOT NULL,
    emr_id TEXT,
    emr_reference TEXT
);

CREATE TABLE universal.attribute
(
    id NUMERIC(6,3) NOT NULL PRIMARY KEY,
    name TEXT
);

CREATE TABLE universal.entry_attribute
(
    id BIGSERIAL NOT NULL PRIMARY KEY,
    entry_id BIGINT NOT NULL REFERENCES universal.entry(id),
    attribute_id NUMERIC(6,3) NOT NULL REFERENCES universal.attribute(id),
    code_system TEXT,
    code_value TEXT,
    text_value TEXT,
    date_value DATE,

    emr_id TEXT,
    emr_reference TEXT,
    emr_effective_date TIMESTAMPTZ NOT NULL,
    hdc_effective_date TIMESTAMPTZ NOT NULL DEFAULT (NOW())
);

CREATE TABLE universal.state
(
    id BIGSERIAL NOT NULL PRIMARY KEY,
    record_type TEXT NOT NULL,
    record_id BIGINT NOT NULL,
    state TEXT,
    effective_date TIMESTAMPTZ
);
