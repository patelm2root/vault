\connect vault
DROP SCHEMA IF EXISTS universal CASCADE;  
--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.2
-- Dumped by pg_dump version 9.6.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: universal; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA universal;


ALTER SCHEMA universal OWNER TO postgres;

SET search_path = universal, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: attribute; Type: TABLE; Schema: universal; Owner: postgres
--

CREATE TABLE attribute (
    id numeric(6,3) NOT NULL,
    name text
);


ALTER TABLE attribute OWNER TO postgres;

--
-- Name: clinic; Type: TABLE; Schema: universal; Owner: postgres
--

CREATE TABLE clinic (
    id bigint NOT NULL,
    name text NOT NULL,
    hdc_reference text NOT NULL,
    emr_id text,
    emr_reference text
);


ALTER TABLE clinic OWNER TO postgres;

--
-- Name: clinic_id_seq; Type: SEQUENCE; Schema: universal; Owner: postgres
--

CREATE SEQUENCE clinic_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE clinic_id_seq OWNER TO postgres;

--
-- Name: clinic_id_seq; Type: SEQUENCE OWNED BY; Schema: universal; Owner: postgres
--

ALTER SEQUENCE clinic_id_seq OWNED BY clinic.id;


--
-- Name: entry; Type: TABLE; Schema: universal; Owner: postgres
--

CREATE TABLE entry (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    emr_table text NOT NULL,
    emr_id text,
    emr_reference text
);


ALTER TABLE entry OWNER TO postgres;

--
-- Name: entry_attribute; Type: TABLE; Schema: universal; Owner: postgres
--

CREATE TABLE entry_attribute (
    id bigint NOT NULL,
    entry_id bigint NOT NULL,
    attribute_id numeric(6,3) NOT NULL,
    code_system text,
    code_value text,
    text_value text,
    date_value date,
    boolean_value boolean,
    numeric_value numeric(18,6),
    emr_id text,
    emr_reference text,
    emr_effective_date timestamp with time zone NOT NULL,
    hdc_effective_date timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE entry_attribute OWNER TO postgres;

--
-- Name: entry_attribute_id_seq; Type: SEQUENCE; Schema: universal; Owner: postgres
--

CREATE SEQUENCE entry_attribute_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE entry_attribute_id_seq OWNER TO postgres;

--
-- Name: entry_attribute_id_seq; Type: SEQUENCE OWNED BY; Schema: universal; Owner: postgres
--

ALTER SEQUENCE entry_attribute_id_seq OWNED BY entry_attribute.id;


--
-- Name: entry_id_seq; Type: SEQUENCE; Schema: universal; Owner: postgres
--

CREATE SEQUENCE entry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE entry_id_seq OWNER TO postgres;

--
-- Name: entry_id_seq; Type: SEQUENCE OWNED BY; Schema: universal; Owner: postgres
--

ALTER SEQUENCE entry_id_seq OWNED BY entry.id;


--
-- Name: patient; Type: TABLE; Schema: universal; Owner: postgres
--

CREATE TABLE patient (
    id bigint NOT NULL,
    clinic_id bigint NOT NULL,
    emr_id text,
    emr_reference text
);


ALTER TABLE patient OWNER TO postgres;

--
-- Name: patient_id_seq; Type: SEQUENCE; Schema: universal; Owner: postgres
--

CREATE SEQUENCE patient_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE patient_id_seq OWNER TO postgres;

--
-- Name: patient_id_seq; Type: SEQUENCE OWNED BY; Schema: universal; Owner: postgres
--

ALTER SEQUENCE patient_id_seq OWNED BY patient.id;


--
-- Name: patient_practitioner; Type: TABLE; Schema: universal; Owner: postgres
--

CREATE TABLE patient_practitioner (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    practitioner_id bigint NOT NULL,
    emr_id text,
    emr_reference text
);


ALTER TABLE patient_practitioner OWNER TO postgres;

--
-- Name: patient_practitioner_id_seq; Type: SEQUENCE; Schema: universal; Owner: postgres
--

CREATE SEQUENCE patient_practitioner_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE patient_practitioner_id_seq OWNER TO postgres;

--
-- Name: patient_practitioner_id_seq; Type: SEQUENCE OWNED BY; Schema: universal; Owner: postgres
--

ALTER SEQUENCE patient_practitioner_id_seq OWNED BY patient_practitioner.id;


--
-- Name: practitioner; Type: TABLE; Schema: universal; Owner: postgres
--

CREATE TABLE practitioner (
    id bigint NOT NULL,
    clinic_id bigint NOT NULL,
    name text,
    identifier text NOT NULL,
    identifier_type text NOT NULL,
    emr_id text,
    emr_reference text
);


ALTER TABLE practitioner OWNER TO postgres;

--
-- Name: practitioner_id_seq; Type: SEQUENCE; Schema: universal; Owner: postgres
--

CREATE SEQUENCE practitioner_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE practitioner_id_seq OWNER TO postgres;

--
-- Name: practitioner_id_seq; Type: SEQUENCE OWNED BY; Schema: universal; Owner: postgres
--

ALTER SEQUENCE practitioner_id_seq OWNED BY practitioner.id;


--
-- Name: state; Type: TABLE; Schema: universal; Owner: postgres
--

CREATE TABLE state (
    id bigint NOT NULL,
    record_type text NOT NULL,
    record_id bigint NOT NULL,
    state text,
    effective_date timestamp with time zone,
    emr_id text,
    emr_reference text
);


ALTER TABLE state OWNER TO postgres;

--
-- Name: state_id_seq; Type: SEQUENCE; Schema: universal; Owner: postgres
--

CREATE SEQUENCE state_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE state_id_seq OWNER TO postgres;

--
-- Name: state_id_seq; Type: SEQUENCE OWNED BY; Schema: universal; Owner: postgres
--

ALTER SEQUENCE state_id_seq OWNED BY state.id;


--
-- Name: clinic id; Type: DEFAULT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY clinic ALTER COLUMN id SET DEFAULT nextval('clinic_id_seq'::regclass);


--
-- Name: entry id; Type: DEFAULT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY entry ALTER COLUMN id SET DEFAULT nextval('entry_id_seq'::regclass);


--
-- Name: entry_attribute id; Type: DEFAULT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY entry_attribute ALTER COLUMN id SET DEFAULT nextval('entry_attribute_id_seq'::regclass);


--
-- Name: patient id; Type: DEFAULT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY patient ALTER COLUMN id SET DEFAULT nextval('patient_id_seq'::regclass);


--
-- Name: patient_practitioner id; Type: DEFAULT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY patient_practitioner ALTER COLUMN id SET DEFAULT nextval('patient_practitioner_id_seq'::regclass);


--
-- Name: practitioner id; Type: DEFAULT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY practitioner ALTER COLUMN id SET DEFAULT nextval('practitioner_id_seq'::regclass);


--
-- Name: state id; Type: DEFAULT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY state ALTER COLUMN id SET DEFAULT nextval('state_id_seq'::regclass);


--
-- Name: attribute attribute_pkey; Type: CONSTRAINT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY attribute
    ADD CONSTRAINT attribute_pkey PRIMARY KEY (id);


--
-- Name: clinic clinic_pkey; Type: CONSTRAINT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY clinic
    ADD CONSTRAINT clinic_pkey PRIMARY KEY (id);


--
-- Name: entry_attribute entry_attribute_pkey; Type: CONSTRAINT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY entry_attribute
    ADD CONSTRAINT entry_attribute_pkey PRIMARY KEY (id);


--
-- Name: entry entry_pkey; Type: CONSTRAINT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY entry
    ADD CONSTRAINT entry_pkey PRIMARY KEY (id);


--
-- Name: patient patient_pkey; Type: CONSTRAINT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY patient
    ADD CONSTRAINT patient_pkey PRIMARY KEY (id);


--
-- Name: patient_practitioner patient_practitioner_pkey; Type: CONSTRAINT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY patient_practitioner
    ADD CONSTRAINT patient_practitioner_pkey PRIMARY KEY (id);


--
-- Name: practitioner practitioner_pkey; Type: CONSTRAINT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY practitioner
    ADD CONSTRAINT practitioner_pkey PRIMARY KEY (id);


--
-- Name: state state_pkey; Type: CONSTRAINT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY state
    ADD CONSTRAINT state_pkey PRIMARY KEY (id);


--
-- Name: idx_entry_attribute_attribute_id; Type: INDEX; Schema: universal; Owner: postgres
--

CREATE INDEX idx_entry_attribute_attribute_id ON entry_attribute USING btree (attribute_id);


--
-- Name: idx_entry_attribute_code_system; Type: INDEX; Schema: universal; Owner: postgres
--

CREATE INDEX idx_entry_attribute_code_system ON entry_attribute USING btree (code_system);


--
-- Name: idx_entry_attribute_code_value; Type: INDEX; Schema: universal; Owner: postgres
--

CREATE INDEX idx_entry_attribute_code_value ON entry_attribute USING btree (code_value);


--
-- Name: idx_entry_attribute_date_value; Type: INDEX; Schema: universal; Owner: postgres
--

CREATE INDEX idx_entry_attribute_date_value ON entry_attribute USING btree (date_value);


--
-- Name: idx_entry_attribute_entry_id; Type: INDEX; Schema: universal; Owner: postgres
--

CREATE INDEX idx_entry_attribute_entry_id ON entry_attribute USING btree (entry_id);


--
-- Name: idx_entry_attribute_text_value; Type: INDEX; Schema: universal; Owner: postgres
--

CREATE INDEX idx_entry_attribute_text_value ON entry_attribute USING btree (text_value);


--
-- Name: idx_entry_emr; Type: INDEX; Schema: universal; Owner: postgres
--

CREATE INDEX idx_entry_emr ON entry USING btree (emr_table, emr_id, id);


--
-- Name: idx_entry_id; Type: INDEX; Schema: universal; Owner: postgres
--

CREATE UNIQUE INDEX idx_entry_id ON entry USING btree (id);


--
-- Name: idx_entry_patient_id; Type: INDEX; Schema: universal; Owner: postgres
--

CREATE INDEX idx_entry_patient_id ON entry USING btree (patient_id);


--
-- Name: idx_id; Type: INDEX; Schema: universal; Owner: postgres
--

CREATE UNIQUE INDEX idx_id ON patient USING btree (id);


--
-- Name: INDEX idx_id; Type: COMMENT; Schema: universal; Owner: postgres
--

COMMENT ON INDEX idx_id IS 'Unique index on the primary key';


--
-- Name: state_effective_date_id_idx; Type: INDEX; Schema: universal; Owner: postgres
--

CREATE INDEX state_effective_date_id_idx ON state USING btree (effective_date DESC NULLS LAST, id DESC NULLS LAST);


--
-- Name: state_record_id_record_type_idx; Type: INDEX; Schema: universal; Owner: postgres
--

CREATE INDEX state_record_id_record_type_idx ON state USING btree (record_id, record_type);


--
-- Name: entry_attribute entry_attribute_attribute_id_fkey; Type: FK CONSTRAINT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY entry_attribute
    ADD CONSTRAINT entry_attribute_attribute_id_fkey FOREIGN KEY (attribute_id) REFERENCES attribute(id);


--
-- Name: entry_attribute entry_attribute_entry_id_fkey; Type: FK CONSTRAINT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY entry_attribute
    ADD CONSTRAINT entry_attribute_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES entry(id);


--
-- Name: entry entry_patient_id_fkey; Type: FK CONSTRAINT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY entry
    ADD CONSTRAINT entry_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES patient(id);


--
-- Name: patient patient_clinic_id_fkey; Type: FK CONSTRAINT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY patient
    ADD CONSTRAINT patient_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinic(id);


--
-- Name: patient_practitioner patient_practitioner_patient_id_fkey; Type: FK CONSTRAINT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY patient_practitioner
    ADD CONSTRAINT patient_practitioner_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES patient(id);


--
-- Name: patient_practitioner patient_practitioner_practitioner_id_fkey; Type: FK CONSTRAINT; Schema: universal; Owner: postgres
--

ALTER TABLE ONLY patient_practitioner
    ADD CONSTRAINT patient_practitioner_practitioner_id_fkey FOREIGN KEY (practitioner_id) REFERENCES practitioner(id);


--
-- PostgreSQL database dump complete
--

