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
-- Name: api; Type: SCHEMA; Schema: -; Owner: postgres
--
CREATE SCHEMA api;
ALTER SCHEMA api OWNER TO postgres;
--
-- Name: concept; Type: SCHEMA; Schema: -; Owner: postgres
--
CREATE SCHEMA concept;
ALTER SCHEMA concept OWNER TO postgres;
--
-- Name: indicator; Type: SCHEMA; Schema: -; Owner: postgres
--
CREATE SCHEMA indicator;
ALTER SCHEMA indicator OWNER TO postgres;
--
-- Name: test; Type: SCHEMA; Schema: -; Owner: postgres
--
CREATE SCHEMA test;
ALTER SCHEMA test OWNER TO postgres;
--
-- Name: universal; Type: SCHEMA; Schema: -; Owner: postgres
--
CREATE SCHEMA universal;
ALTER SCHEMA universal OWNER TO postgres;
--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--
CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;
--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--
COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';
--
-- Name: tablefunc; Type: EXTENSION; Schema: -; Owner: 
--
CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA public;
--
-- Name: EXTENSION tablefunc; Type: COMMENT; Schema: -; Owner: 
--
COMMENT ON EXTENSION tablefunc IS 'functions that manipulate whole tables, including crosstab';
SET search_path = api, pg_catalog;
--
-- Name: perform_update(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--
CREATE FUNCTION perform_update(p_change_id integer, p_statement text) RETURNS void
    LANGUAGE plpgsql
    AS $$	BEGIN    --Execute the statement    EXECUTE p_statement;    --Update the version table to show that we have performed the update    INSERT INTO api.change(change_id, statement, update_date) VALUES (p_change_id, p_statement, now());END;$$;
ALTER FUNCTION api.perform_update(p_change_id integer, p_statement text) OWNER TO postgres;
--
-- Name: retrieve_version(); Type: FUNCTION; Schema: api; Owner: postgres
--
CREATE FUNCTION retrieve_version() RETURNS integer
    LANGUAGE plpgsql
    AS $$  	BEGIN      RETURN (SELECT MAX(change_id) FROM api.change);  END;  $$;
ALTER FUNCTION api.retrieve_version() OWNER TO postgres;
--
-- Name: run_aggregate(text, text, text, date); Type: FUNCTION; Schema: api; Owner: postgres
--
CREATE FUNCTION run_aggregate(p_indicator text, p_clinic text, p_provider text, p_effective_date date) RETURNS TABLE(numerator integer, denominator integer)
    LANGUAGE plpgsql
    AS $$    DECLARE    v_numerator int[];    v_denominator int[];    BEGIN		EXECUTE format('SELECT * FROM indicator.%s(p_clinic_reference:=''%s''::text, p_practitioner_msp:=''%s''::text, p_effective_date:=''%s''::date)', p_indicator, p_clinic, p_provider, p_effective_date)		INTO v_numerator, v_denominator;		RETURN QUERY		SELECT (SELECT COALESCE(array_length(v_numerator, 1), 0)) as numerator,			   (SELECT COALESCE(array_length(v_denominator, 1), 0)) as denominator;    END;    $$;
ALTER FUNCTION api.run_aggregate(p_indicator text, p_clinic text, p_provider text, p_effective_date date) OWNER TO postgres;
SET search_path = concept, pg_catalog;
--
-- Name: clinic(text, date); Type: FUNCTION; Schema: concept; Owner: postgres
--
CREATE FUNCTION clinic(p_clinic_reference text, p_effective_date date) RETURNS TABLE(patient_id bigint)
    LANGUAGE plpgsql
    AS $$BEGIN	/** 
	 * Description: returns the patients that are associated with a clinic
	 */     RETURN QUERY        SELECT p.id as patient_id        FROM universal.patient as p        JOIN universal.clinic as c            ON p.clinic_id = c.id        WHERE             c.hdc_reference = p_clinic_reference;END  $$;
ALTER FUNCTION concept.clinic(p_clinic_reference text, p_effective_date date) OWNER TO postgres;
--
-- Name: concept(text, date); Type: FUNCTION; Schema: concept; Owner: postgres
--
CREATE FUNCTION concept(p_concept_key text, p_effective_date date) RETURNS TABLE(patient_id bigint, entry_id bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
	/** 
	 * Description: returns all patients that are associated with a specific concept	 
	 */ 
    RETURN QUERY
   SELECT DISTINCT e.patient_id,
          e.id as entry_id
     FROM universal.mat_entry_attribute as ea
      
     -- Join back to get the patient id
     JOIN universal.entry as e
       ON e.id = ea.entry_id
     -- Join state to see if this record was active on the effective date
     JOIN universal.mat_state as es
       ON ea.entry_id = es.record_id
      AND es.record_type = 'entry'
      AND p_effective_date BETWEEN es.effective_start_date and es.effective_end_date
     JOIN concept.code_mapping as cm
       ON cm.concept_key = p_concept_key  
      AND cm.attribute_id = ea.attribute_id
       -- Check if the concept matches
      AND LOWER(cm.code_system) = LOWER(ea.code_system)
      AND 
        -- Regex match on code_value
        ((ea.code_value ~* cm.code_pattern)
        OR 
        -- Regex match on text_value
        (ea.text_value ~* cm.text_pattern))
       
    WHERE 
      -- Only look at the effective attribute value for the given effective date
      p_effective_date BETWEEN ea.emr_effective_start_date AND ea.emr_effective_end_date;
          
END
$$;
ALTER FUNCTION concept.concept(p_concept_key text, p_effective_date date) OWNER TO postgres;
--
-- Name: concept_in_date_range(text, date, date); Type: FUNCTION; Schema: concept; Owner: postgres
--
CREATE FUNCTION concept_in_date_range(p_concept_key text, p_effective_start_date date, p_effective_end_date date) RETURNS TABLE(patient_id bigint, entry_id bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
	/** 
	 * Description: returns all patients that are associated with a specific concept
					within a specified date range.  Any point within the date range being
					associated with the concept is considered a match.
	 */ 
    RETURN QUERY
   SELECT DISTINCT e.patient_id,
          e.id as entry_id
     FROM universal.mat_entry_attribute as ea
      
     -- Join back to get the patient id
     JOIN universal.entry as e
       ON e.id = ea.entry_id
     -- Join state to see if this record was active on the effective date
     JOIN universal.mat_active_state as es
       ON ea.entry_id = es.record_id
      AND es.record_type = 'entry'
      AND es.effective_start_date <= p_effective_end_date and es.effective_end_date >= p_effective_start_date
     JOIN concept.code_mapping as cm
       ON cm.concept_key = p_concept_key  
      AND cm.attribute_id = ea.attribute_id
       -- Check if the concept matches
      AND cm.code_system = ea.code_system
      AND 
        -- Regex match on code_value
        ((ea.code_value ~* cm.code_pattern)
        OR 
        -- Regex match on text_value
        (ea.text_value ~* cm.text_pattern))
       
    WHERE 
      -- Only look at the effective attribute value for the given effective date range
      ea.emr_effective_start_date <= p_effective_end_date AND ea.emr_effective_end_date >= p_effective_start_date;
          
END
$$;
ALTER FUNCTION concept.concept_in_date_range(p_concept_key text, p_effective_start_date date, p_effective_end_date date) OWNER TO postgres;
--
-- Name: encounter_count(date, date); Type: FUNCTION; Schema: concept; Owner: postgres
--
CREATE FUNCTION encounter_count(p_min_date date, p_max_date date) RETURNS TABLE(entry_id bigint)
    LANGUAGE plpgsql
    AS $$BEGIN
	/** 
	 * Description: counts the number of patient encounters that occurred between the start and end date
	 * Definition:  
	 * 		- an encounter is defined as the existance of a valid encounter date attribute between the parameter date range
	 *		- a valid encounter date must be within the emr effective attribute dates and the entry effective dates (simultaneous) 
	 */ 
	    RETURN QUERY
    SELECT DISTINCT
		ea.entry_id
	FROM universal.mat_entry_attribute as ea
	JOIN universal.mat_active_state as s
		on ea.entry_id = s.record_id
		AND record_type = 'entry'
	WHERE
		-- Attribute code for encounter date
		ea.attribute_id = 7.001 
		/** Need to test for a three-way overlap of attribute_effective_dates / entry_effective_dates / parameter_dates **/		
		-- test parameter range overlaps the two effective ranges
		AND p_min_date <= ea.emr_effective_end_date AND p_min_date <=s.effective_end_date
		AND p_max_date >= ea.emr_effective_start_date AND p_max_date >= s.effective_start_date
		-- test that both effective ranges overlap
		AND ea.emr_effective_start_date <= s.effective_end_date AND ea.emr_effective_end_date >= s.effective_start_date
		-- test that the actual encounter date is within the parameter range
		AND ea.date_value BETWEEN p_min_date and p_max_date;END  $$;
ALTER FUNCTION concept.encounter_count(p_min_date date, p_max_date date) OWNER TO postgres;
--
-- Name: encounters(date, date); Type: FUNCTION; Schema: concept; Owner: postgres
--
CREATE FUNCTION encounters(p_min_date date, p_max_date date) RETURNS TABLE(entry_id bigint, patient_id bigint)
    LANGUAGE plpgsql
    AS $$BEGIN    RETURN QUERY    WITH encounters AS (        SELECT             ea.entry_id,
            ea.date_value as encounter_date,            RANK() OVER( PARTITION BY ea.entry_id ORDER BY ea.emr_effective_date DESC, ea.id DESC, s.effective_date DESC, s.id DESC) as rank        FROM universal.entry_attribute as ea
        JOIN universal.state as s
			ON ea.entry_id = s.record_id
			AND s.record_type = 'entry'
			AND s.effective_date BETWEEN p_min_date and p_max_date
        WHERE 
			ea.attribute_id = 7.001
			AND ea.emr_effective_date BETWEEN p_min_date AND p_max_date	)    SELECT         e.entry_id,
        en.patient_id    FROM encounters as e
    JOIN universal.entry as en
		ON e.entry_id = en.id    WHERE         rank = 1;END  $$;
ALTER FUNCTION concept.encounters(p_min_date date, p_max_date date) OWNER TO postgres;
--
-- Name: immunization(text, date); Type: FUNCTION; Schema: concept; Owner: postgres
--
CREATE FUNCTION immunization(p_concept_key text, p_effective_date date) RETURNS TABLE(patient_id bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
	/** 
	 * Description: returns all patients that received an immunization prior to the effective date
	 */ 
   RETURN QUERY
   SELECT
        e.patient_id
    FROM universal.entry as e
    -- Administration date of the vaccine
    JOIN universal.mat_entry_attribute as ea_date
        ON e.id = ea_date.entry_id
        AND ea_date.attribute_id = 11.003
    WHERE 
        -- Check that the patient was administered the vaccine
        e.id IN (SELECT entry_id FROM concept.concept(p_concept_key, p_effective_date))
        -- Check that the vaccination was prior to the effective date of the query
        AND p_effective_date BETWEEN ea_date.emr_effective_start_date AND ea_date.emr_effective_end_date;
          
END
$$;
ALTER FUNCTION concept.immunization(p_concept_key text, p_effective_date date) OWNER TO postgres;
--
-- Name: observation(text, date, date, double precision, double precision); Type: FUNCTION; Schema: concept; Owner: postgres
--
CREATE FUNCTION observation(p_concept_key text, p_min_date date, p_max_date date, p_bottom_value double precision, p_top_value double precision) RETURNS TABLE(patient_id bigint)
    LANGUAGE plpgsql
    AS $_$BEGIN    /** 
	 * Description: Finds patients that had a concept observation with a specific value range in a given date range
	 * Definition:  
	 * 		- entry state is already verified through concept.concept()
	 */     RETURN QUERY	SELECT DISTINCT		p.patient_id	-- Find all patients with an observation of p_concept_key type	FROM concept.concept(p_concept_key, now()::date) as p	-- for observation values	JOIN universal.mat_entry_attribute as ea		ON ea.entry_id = p.entry_id		AND ea.attribute_id = 009.003
		AND ea.emr_effective_start_date <= p_max_date
		AND ea.emr_effective_end_date >= p_min_date    WHERE         --Short circuit and eliminate records that aren't floats
		ea.text_value ~ '^[-+]?[0-9]*\.?[0-9]+$'
        AND ((p_bottom_value IS NULL OR p_top_value IS NULL) OR ea.text_value::FLOAT BETWEEN p_bottom_value AND p_top_value);END  $_$;
ALTER FUNCTION concept.observation(p_concept_key text, p_min_date date, p_max_date date, p_bottom_value double precision, p_top_value double precision) OWNER TO postgres;
--
-- Name: patient(timestamp without time zone, boolean, interval, interval, character varying); Type: FUNCTION; Schema: concept; Owner: postgres
--
CREATE FUNCTION patient(p_effective_date timestamp without time zone, p_active boolean DEFAULT true, p_min_age interval DEFAULT NULL::interval, p_max_age interval DEFAULT NULL::interval, p_gender character varying DEFAULT NULL::character(1)) RETURNS TABLE(patient_id bigint)
    LANGUAGE sql
    AS $$    SELECT DISTINCT            p.id as patient_id       FROM universal.patient as p;      /*     WHERE (p_gender IS NULL OR (EXISTS(SELECT 1                                           FROM universal.entry as e                                          JOIN universal.entry_attribute as a                                            ON a.entry_id = e.id                                         WHERE e.patient_id = p.id                                           AND  LEFT JOIN universal.entry as e_gender        ON e_gender.patient_id = p.id LEFT JOIN universal.entry_attribute as ea_gender        ON ea_gender.entry_id = e_gender.id       AND ea_gender.attribute_id = '005.002'               p.id = ea_gender.patient_id     WHERE (min_age IS NULL OR age(patient.effective_date, p_info.birth_date) >= min_age)       AND (max_age IS NULL OR age(patient.effective_date, p_info.birth_date) <= max_age)       AND (patient.gender IS NULL OR p_info.gender = patient.gender)AND (	(active IS NULL)	OR	(active = TRUE 		AND universal.entry.occurrence_date >= (patient.effective_date - '3 year'::interval) -- temporary active check of any entry in the last 3 years		)	OR	(active = FALSE 		AND NOT EXISTS (SELECT 1                    FROM universal.entry                  WHERE patient_id = p.id                  AND universal.entry.occurrence_date >= (patient.effective_date - '3 year'::interval) -- temporary active check of any entry in the last 3 years)                  )	)*/$$;
ALTER FUNCTION concept.patient(p_effective_date timestamp without time zone, p_active boolean, p_min_age interval, p_max_age interval, p_gender character varying) OWNER TO postgres;
--
-- Name: patient_active(date); Type: FUNCTION; Schema: concept; Owner: postgres
--
CREATE FUNCTION patient_active(p_effective_date date) RETURNS TABLE(patient_id bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
	RETURN QUERY    /* Finds all active patients */    SELECT distinct e.patient_id    FROM universal.entry as e    JOIN universal.state as s        ON e.id = s.record_id        AND s.record_type = 'entry'    WHERE         s.effective_date <= p_effective_date        AND s.effective_date >= p_effective_date - INTERVAL '3 years';
END$$;
ALTER FUNCTION concept.patient_active(p_effective_date date) OWNER TO postgres;
--
-- Name: patient_age(date, integer, integer); Type: FUNCTION; Schema: concept; Owner: postgres
--
CREATE FUNCTION patient_age(p_effective_date date, p_min_age integer DEFAULT NULL::integer, p_max_age integer DEFAULT NULL::integer) RETURNS TABLE(patient_id bigint)
    LANGUAGE sql
    AS $$/*     Description: Returns the list of patients that are a certain min/max age on the effective date.*/	WITH patientAges as (		SELECT			e.patient_id,			e.id as entry_id,			age(p_effective_date, ea.date_value) as age,			RANK() OVER (PARTITION BY ea.entry_id ORDER BY ea.emr_effective_date DESC, ea.id DESC) as age_rank		FROM universal.entry_attribute as ea		JOIN universal.entry as e            ON ea.entry_id = e.id		WHERE attribute_id = 5.001			AND ea.emr_effective_date <= p_effective_date	),	ActiveState as (        SELECT DISTINCT            p.patient_id,            es.state,            RANK() OVER(PARTITION BY p.entry_id ORDER BY es.effective_date DESC, es.id DESC) as entry_state_rank        FROM patientAges as p        JOIN universal.state as es            ON p.entry_id = es.record_id            AND es.record_type = 'entry'            AND es.effective_date < p_effective_date        WHERE             -- Check patient minimum age            (p_min_age IS NULL OR date_part('year', p.age) >= p_min_age)            AND             -- Check patient maximum age            (p_max_age IS NULL OR date_part('year', p.age) <= p_max_age)            -- Check for the latest attribute value            AND age_rank = 1)    SELECT         patient_id    FROM ActiveState as act    JOIN concept.code_mapping as cm_state        ON COALESCE(act.state, 'active') ~* cm_state.text_pattern        AND cm_state.concept_key = 'active state'    WHERE act.entry_state_rank = 1;$$;
ALTER FUNCTION concept.patient_age(p_effective_date date, p_min_age integer, p_max_age integer) OWNER TO postgres;
--
-- Name: practitioner(text, date); Type: FUNCTION; Schema: concept; Owner: postgres
--
CREATE FUNCTION practitioner(p_practitioner_msp text, p_effective_date date) RETURNS TABLE(patient_id bigint)
    LANGUAGE plpgsql
    AS $$BEGIN    /* p_effective_date is not being used yet */    RETURN QUERY        SELECT pp.patient_id        FROM universal.practitioner as p        JOIN universal.patient_practitioner as pp            ON p.id = pp.practitioner_id        WHERE             p.identifier_type = 'MSP'            AND p.identifier = p_practitioner_MSP;END  $$;
ALTER FUNCTION concept.practitioner(p_practitioner_msp text, p_effective_date date) OWNER TO postgres;
--
-- Name: prescription_active(text, date); Type: FUNCTION; Schema: concept; Owner: postgres
--
CREATE FUNCTION prescription_active(p_concept_key text, p_effective_date date) RETURNS TABLE(patient_id bigint)
    LANGUAGE plpgsql
    AS $$BEGIN    /*        Description:            Returns the list of patients that were actively taking a medication on a given date    */        RETURN QUERY        WITH starts AS (            -- Find the most recent start date for this prescription            SELECT                ea.entry_id,                ea.date_value as start_date,                RANK() OVER (PARTITION BY ea.entry_id ORDER BY ea.emr_effective_date DESC, ea.id DESC) as start_rank            FROM universal.entry_attribute as ea            WHERE attribute_id = 12.008                AND ea.emr_effective_date <= p_effective_date        )        ,stops AS (            -- Find the most recent stop date for this prescription            SELECT                ea.entry_id,                ea.date_value as stop_date,                RANK() OVER (PARTITION BY ea.entry_id ORDER BY ea.emr_effective_date DESC, ea.id DESC) as stop_rank            FROM universal.entry_attribute as ea            WHERE attribute_id = 12.009                AND ea.emr_effective_date <= p_effective_date         )        ,prescriptions AS (            -- Find the most recent status for this prescription as a whole for the given p_effective_date            SELECT                 e.patient_id,                 RANK() OVER(PARTITION BY ea.entry_id ORDER BY ea.emr_effective_date DESC, ea.id DESC) as med_rank            FROM universal.entry as e            JOIN universal.entry_attribute as ea                ON e.id = ea.entry_id                AND ea.attribute_id = 12.001            JOIN starts                ON e.id = starts.entry_id                AND starts.start_rank = 1            JOIN stops                ON e.id = stops.entry_id                AND stops.stop_rank = 1            WHERE                 p_effective_date BETWEEN starts.start_date AND stops.stop_date                AND (p_concept_key IS NULL OR e.patient_id IN (SELECT ms.patient_id FROM concept.concept(p_concept_key, p_effective_date) as ms)))        -- Find the most recent medication type        SELECT 			p.patient_id        FROM prescriptions as p        WHERE             p.med_rank = 1;END  $$;
ALTER FUNCTION concept.prescription_active(p_concept_key text, p_effective_date date) OWNER TO postgres;
--
-- Name: prescription_count(date, date); Type: FUNCTION; Schema: concept; Owner: postgres
--
CREATE FUNCTION prescription_count(p_start_effective_date date, p_end_effective_date date) RETURNS TABLE(entry_id bigint)
    LANGUAGE plpgsql
    AS $$DECLARE v_active_state text;
BEGIN
    /*
        Description:
            Returns the the list of prescription entries that were being actively taken by a patient between the start/end date.
    */        /** Active State Regex Expression **/    SELECT text_pattern    INTO v_active_state    FROM concept.code_mapping    WHERE concept_key = 'active state'    LIMIT 1;    
    RETURN QUERY
        WITH prescriptions AS (
            -- Find the most recent status for this prescription as a whole for the given effective dates
            SELECT 
                e.id as entry_id,                 s.state,
                RANK() OVER(PARTITION BY ea.entry_id ORDER BY ea.emr_effective_start_date DESC) as med_rank
            FROM universal.entry as e            -- Prescription entry
            JOIN universal.mat_entry_attribute as ea
                ON e.id = ea.entry_id
                AND ea.attribute_id = 12.001            -- Prescription start date            JOIN universal.mat_entry_attribute as starts                ON e.id = starts.entry_id                AND starts.attribute_id = 12.008                AND p_start_effective_date <= starts.emr_effective_end_date                AND p_end_effective_date >= starts.emr_effective_start_date            -- Prescription stop date            JOIN universal.mat_entry_attribute as stops                ON e.id = stops.entry_id                AND stops.attribute_id = 12.009                AND p_start_effective_date <= stops.emr_effective_end_date                AND p_end_effective_date >= stops.emr_effective_start_date             -- Ensure entry state is active            JOIN universal.mat_active_state as s                ON e.id = s.record_id                 AND s.record_type = 'entry'                AND s.effective_start_date <= p_end_effective_date                AND s.effective_end_date >= p_start_effective_date
            WHERE 
                starts.date_value <= p_end_effective_date AND stops.date_value >= p_start_effective_date)
                
        SELECT 
			p.entry_id
        FROM prescriptions as p
        WHERE 
            p.med_rank = 1            AND p.state ~* v_active_state;
END  
$$;
ALTER FUNCTION concept.prescription_count(p_start_effective_date date, p_end_effective_date date) OWNER TO postgres;
--
-- Name: prescription_minimum_meds(date, integer); Type: FUNCTION; Schema: concept; Owner: postgres
--
CREATE FUNCTION prescription_minimum_meds(p_effective_date date, p_min_med integer) RETURNS TABLE(patient_id bigint)
    LANGUAGE plpgsql
    AS $$BEGIN	/* 		Description: Returns a list of patients that have at least the 				minumum number of active prescriptions specified.	*/    RETURN QUERY        WITH prescriptions as (            SELECT                 e.patient_id,                 e.id,                ea.code_value as prescription_id,                 start_ea.date_value as start_date,                stop_ea.date_value as stop_date,                es.state,                RANK() OVER(PARTITION BY e.id ORDER BY es.effective_date DESC, ea.emr_effective_date DESC, start_ea.emr_effective_date DESC, stop_ea.emr_effective_date DESC, es.id DESC, ea.id DESC, start_ea.id DESC, stop_ea.id DESC) as rank            FROM universal.entry as e            -- Entry state            JOIN universal.state as es                ON es.record_type = 'entry'                AND es.record_id = e.id            -- Prescription type            JOIN universal.entry_attribute as ea                ON e.id = ea.entry_id                AND ea.attribute_id = 12.001            JOIN universal.entry_attribute as start_ea                ON e.id = start_ea.entry_id                AND start_ea.attribute_id = 12.008            JOIN universal.entry_attribute as stop_ea                ON e.id = stop_ea.entry_id                AND stop_ea.attribute_id = 12.009            WHERE                 es.effective_date < p_effective_date        )        SELECT            p.patient_id        FROM prescriptions as p        JOIN concept.code_mapping as cm_state            ON p.state ~* cm_state.text_pattern            AND cm_state.concept_key = 'active state'        WHERE p.rank = 1            AND p_effective_date BETWEEN p.start_date AND p.stop_date        GROUP BY             p.patient_id        HAVING count(distinct p.prescription_id) >= p_min_med;    END   $$;
ALTER FUNCTION concept.prescription_minimum_meds(p_effective_date date, p_min_med integer) OWNER TO postgres;
--
-- Name: procedure_in_date_range(text, date, date); Type: FUNCTION; Schema: concept; Owner: postgres
--
CREATE FUNCTION procedure_in_date_range(p_concept_key text, p_effective_start_date date, p_effective_end_date date) RETURNS TABLE(patient_id bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
	/** 
	 * Description: returns all patients that have had a procedure performed in the given date range
	 */ 
   RETURN QUERY
   SELECT
        e.patient_id
    FROM universal.entry as e
    -- Performed date of the procedure
    JOIN universal.mat_entry_attribute as ea_date
        ON e.id = ea_date.entry_id
        AND ea_date.attribute_id = 15.003
    WHERE 
        -- Check that the patient had this procedure performed
        e.id IN (SELECT entry_id FROM concept.concept_in_date_range(p_concept_key, p_effective_start_date, p_effective_end_date))
        -- Check that the performed date was within the given date range
        AND ea_date.date_value BETWEEN p_effective_start_date AND p_effective_end_date
		-- Check that the performed date was active during the given date range
        AND ea_date.emr_effective_start_date <= p_effective_end_date AND ea_date.emr_effective_end_date >= p_effective_start_date;
          
END
$$;
ALTER FUNCTION concept.procedure_in_date_range(p_concept_key text, p_effective_start_date date, p_effective_end_date date) OWNER TO postgres;
SET search_path = indicator, pg_catalog;
--
-- Name: hdc_0014(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0014(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     
BEGIN
	/**
     * Query Title: HDC-0014
     * Query Type:  Ratio
     * Initiative:  Population Health
     * Description: Of active patients, 65+,
     *              how many have a pneumococcal vaccine?
     */
	
    /**** Denominator  ****/
    DROP TABLE IF EXISTS denominator;
    CREATE TEMP TABLE denominator AS
    SELECT 
        p.id::bigint
    FROM universal.patient as p
    WHERE
        -- Active patient
        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))
        -- Age 65 or older
        AND p.id IN (SELECT patient_id FROM concept.patient_age(p_effective_date, 65, 150))
        -- Clinic patient or no clinic
        AND 
			(p_clinic_reference = ''
			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))
        -- Practitioner's patient or no practitioner
        AND 
			(p_practitioner_msp = ''
			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));
        
    /**** Numerator ****/
    v_numerator := ARRAY(
        -- Has active pneumococcal vaccination prior to the effective date. 
        SELECT id
        FROM denominator d
        WHERE d.id IN (SELECT patient_id FROM concept.immunization('pneumococcal', p_effective_date)));
            
    v_denominator := ARRAY(SELECT id from denominator);        
        
END  
$$;
ALTER FUNCTION indicator.hdc_0014(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0020(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0020(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     
BEGIN
	/**
     * Query Title: HDC-0020
     * Query Type:  Ratio
     * Initiative:  Population Health
     * Description: Of active patients, 50 <= age < 75,
     *              how many have a colon cancer screening in the last two years
     *              or a colonoscopy or sigmoidoscopy in the last five years?
     */
	
    /**** Denominator  ****/
    DROP TABLE IF EXISTS denominator;
    CREATE TEMP TABLE denominator AS
    SELECT 
        p.id::bigint
    FROM universal.patient as p
    WHERE
        -- Active patient
        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))
        -- Age between 50 and 75
        AND p.id IN (SELECT patient_id FROM concept.patient_age(p_effective_date, 50, 74))
        -- Clinic patient or no clinic
        AND 
			(p_clinic_reference = ''
			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))
        -- Practitioner's patient or no practitioner
        AND 
			(p_practitioner_msp = ''
			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));
        
    /**** Numerator ****/
    v_numerator := ARRAY(
        SELECT DISTINCT id
        FROM denominator d
        WHERE 
            -- Has colon cancer screening in last two years
            d.id IN (SELECT patient_id FROM concept.procedure_in_date_range('colon cancer', (p_effective_date - INTERVAL '2 years')::date, p_effective_date) )
            -- Has colonoscopy in last five years
            OR d.id IN (SELECT patient_id FROM concept.procedure_in_date_range('colonoscopy', (p_effective_date - INTERVAL '5 years')::date, p_effective_date) ));
            
    v_denominator := ARRAY(SELECT id from denominator);        
        
END  
$$;
ALTER FUNCTION indicator.hdc_0020(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0022(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0022(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     
BEGIN
	/**
	 * Query Title: HDC-0022
	 * Query Type:  Ratio
	 * Description: Fasting BS 3y, 46+
	 */
	
    /**** Denominator  ****/
    DROP TABLE IF EXISTS denominator;
    CREATE TEMP TABLE denominator AS
    SELECT 
        p.id::bigint
    FROM universal.patient as p
    WHERE
        -- Active patient
        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))
        -- Age greater than 46
        AND p.id IN (SELECT patient_id FROM concept.patient_age(p_effective_date, 46, 150))
        -- Clinic patient or no clinic
        AND 
			(p_clinic_reference = ''
			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))
        -- Practitioner's patient or no practitioner
        AND 
			(p_practitioner_msp = ''
			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));
        
    /**** Numerator ****/
    v_numerator := ARRAY(
        SELECT DISTINCT id
        FROM denominator d
        WHERE 
            -- has had fasting glucose recorded in last three years
            d.id IN (SELECT patient_id FROM concept.procedure_in_date_range('fasting glucose', (p_effective_date - INTERVAL '3 years')::date, p_effective_date)));
            
    v_denominator := ARRAY(SELECT id from denominator);        
        
END  
$$;
ALTER FUNCTION indicator.hdc_0022(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0053(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0053(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     BEGIN    /**
    * Query Title: HDC-0053
    * Query Type:  Ratio
    * Initiative:  Polypharmacy
    * Description: Of active patients, 65+,
    *              how many have 5+ active meds?
    */
    /**** Denominator  ****/    DROP TABLE IF EXISTS denominator;    CREATE TEMP TABLE denominator AS    SELECT         p.id::bigint    FROM universal.patient as p    WHERE        -- Active patient        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))        -- Age >= 65        AND p.id IN (SELECT patient_id FROM concept.patient_age(p_effective_date, 65))        -- Clinic patient or no clinic        AND 			(p_clinic_reference = ''			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))        -- Practitioner's patient or no practitioner        AND 			(p_practitioner_msp = ''			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));            /**** Numerator ****/    v_numerator := ARRAY(        SELECT id        FROM denominator d        WHERE d.id IN (SELECT patient_id FROM concept.prescription_minimum_meds(p_effective_date, 5)));                v_denominator := ARRAY(SELECT id from denominator);                END  $$;
ALTER FUNCTION indicator.hdc_0053(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0054(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0054(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     BEGIN	/**
	* Query Title: HDC-0054
	* Query Type:  Ratio
	* Initiative:  Polypharmacy
	* Description: Of active patients, 65+,
	*              how many have 10+ active meds?
	*/
    /**** Denominator  ****/    DROP TABLE IF EXISTS denominator;    CREATE TEMP TABLE denominator AS    SELECT         p.id::bigint    FROM universal.patient as p    WHERE        -- Active patient        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))        -- Age >= 65        AND p.id IN (SELECT patient_id FROM concept.patient_age(p_effective_date, 65))        -- Clinic patient or no clinic        AND 			(p_clinic_reference = ''			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))        -- Practitioner's patient or no practitioner        AND 			(p_practitioner_msp = ''			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));            /**** Numerator ****/    v_numerator := ARRAY(        SELECT id        FROM denominator d        WHERE d.id IN (SELECT patient_id FROM concept.prescription_minimum_meds(p_effective_date, 10)));                v_denominator := ARRAY(SELECT id from denominator);                END  $$;
ALTER FUNCTION indicator.hdc_0054(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0056(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0056(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     
BEGIN
    /**
     * Query Title: HDC-0056
     * Query Type:  Ratio
     * Initiative:  Polypharmacy
     * Description: Of active patients, 65+, with impaired renal function,
     *              how many are on digoxin?
     */
	
    /**** Denominator  ****/
    DROP TABLE IF EXISTS denominator;
    CREATE TEMP TABLE denominator AS
    SELECT 
        p.id::bigint
    FROM universal.patient as p
    WHERE
        -- Active patient
        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))
        -- Age 65+
        AND p.id IN (SELECT patient_id FROM concept.patient_age(p_effective_date, 65, 150))
        -- With impaired renal function
        AND p.id IN (SELECT patient_id FROM concept.concept('impaired renal function', p_effective_date))
        -- Clinic patient or no clinic
        AND 
			(p_clinic_reference = ''
			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))
        -- Practitioner's patient or no practitioner
        AND 
			(p_practitioner_msp = ''
			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));
        
    /**** Numerator ****/
    v_numerator := ARRAY(
        SELECT DISTINCT id
        FROM denominator d
        WHERE 
            -- Is actively taking digoxin
            d.id IN (SELECT patient_id FROM concept.prescription_active('digoxin', p_effective_date) ));
            
    v_denominator := ARRAY(SELECT id from denominator);        
        
END  
$$;
ALTER FUNCTION indicator.hdc_0056(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0732(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0732(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     
BEGIN
     /**
     * Query Title: HDC-0732_ChronicPain
     * Query Type:  Ratio
     */
	
    /**** Denominator  ****/
    DROP TABLE IF EXISTS denominator;
    CREATE TEMP TABLE denominator AS
    SELECT 
        p.id::bigint
    FROM universal.patient as p
    WHERE
        -- Active patient
        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))
        -- Clinic patient or no clinic
        AND 
			(p_clinic_reference = ''
			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))
        -- Practitioner's patient or no practitioner
        AND 
			(p_practitioner_msp = ''
			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));
        
    /**** Numerator ****/
    v_numerator := ARRAY(
        SELECT id
        FROM denominator d
        WHERE d.id IN (SELECT patient_id FROM concept.concept('chronic pain', p_effective_date)));
            
    v_denominator := ARRAY(SELECT id from denominator);        
        
END  
$$;
ALTER FUNCTION indicator.hdc_0732(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0831(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0831(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     BEGIN
	/**
	 * Query Title: HDC-0831 DQ Encounter Frquency 
	 * Query Type:  Ratio
	 * Description: % of patients with an encounter in the last 36 months
	 */    /**** Denominator  ****/    DROP TABLE IF EXISTS denominator;    CREATE TEMP TABLE denominator AS    SELECT         p.id::bigint    FROM universal.patient as p    WHERE        -- Active patient        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))        -- Clinic patient or no clinic        AND 			(p_clinic_reference = ''			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))        -- Practitioner's patient or no practitioner        AND 			(p_practitioner_msp = ''			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));            /**** Numerator ****/    v_numerator := ARRAY(        SELECT id        FROM denominator d        WHERE d.id IN (SELECT patient_id FROM concept.encounters((p_effective_date - INTERVAL '3 Years')::date, p_effective_date)));                v_denominator := ARRAY(SELECT id from denominator);                END  $$;
ALTER FUNCTION indicator.hdc_0831(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0832(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0832(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     BEGIN	/**
	 * Query Title: HDC-0832 DQ-DocumentedGender
	 * Query Type:  Ratio
	 * Query Description: % of patients with no documented gender
	 */
    /**** Denominator  ****/    DROP TABLE IF EXISTS denominator;    CREATE TEMP TABLE denominator AS    SELECT         p.id::bigint    FROM universal.patient as p    WHERE        -- Active patient        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))        -- Clinic patient or no clinic        AND 			(p_clinic_reference = ''			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))        -- Practitioner's patient or no practitioner        AND 			(p_practitioner_msp = ''			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));            /**** Numerator ****/    v_numerator := ARRAY(        SELECT id        FROM denominator d        WHERE d.id IN (SELECT patient_id FROM concept.concept('unspecified gender', p_effective_date)));                v_denominator := ARRAY(SELECT id from denominator);                END  $$;
ALTER FUNCTION indicator.hdc_0832(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0833(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0833(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     BEGIN	/**
	 * Query Title: HDC-0833 DQ-InvalidBirthdate
	 * Query Type:  Ratio
	 * Query Description: Count active patients with an invalid date of birth,
	 * excluding anyone over 120 years old
	 */
    /**** Denominator: any active patient  ****/    DROP TABLE IF EXISTS denominator;    CREATE TEMP TABLE denominator AS    SELECT         p.id::bigint    FROM universal.patient as p    WHERE        -- Active patient        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))        -- Clinic patient or no clinic        AND 			(p_clinic_reference = ''			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))        -- Practitioner's patient or no practitioner        AND 			(p_practitioner_msp = ''			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));            /**** Numerator: over 120 years old ****/    v_numerator := ARRAY(
    
		With effectiveBirthDates as (
			SELECT
				ea.date_value as birth_date,
				e.patient_id,
				RANK() OVER(PARTITION BY e.patient_id ORDER BY ea.emr_effective_date DESC, ea.id DESC, s.effective_date DESC, s.id DESC) as rank
			FROM universal.entry_attribute as ea				
			JOIN universal.entry as e
				ON ea.entry_id = e.id
			JOIN universal.state as s
				ON s.record_id = ea.entry_id
				AND s.record_type = 'entry'
				AND s.effective_date <= p_effective_date
			WHERE 
				-- Valid birth date prior to the effective date
				ea.attribute_id = 5.001
				AND ea.emr_effective_date <= p_effective_date
				-- Clinic patient or no clinic
				AND 
					(p_clinic_reference = ''
					OR e.patient_id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))
				-- Practitioner's patient or no practitioner
				AND 
					(p_practitioner_msp = ''
					OR	e.patient_id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date))))
		SELECT
			d.id as patient_id
		FROM denominator as d	-- active patients
		LEFT OUTER JOIN effectiveBirthDates as ebd
			ON d.id = ebd.patient_id
		WHERE 
            ebd.rank = 1
            AND date_part('year', age(p_effective_date, ebd.birth_date)) > 120);                v_denominator := ARRAY(SELECT id from denominator);                END  $$;
ALTER FUNCTION indicator.hdc_0833(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0834(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0834(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     BEGIN	/**
	 * Query Title: HDC-0833 DQ-InvalidBirthdate
	 * Query Type:  Ratio
	 * Query Description: Count active patients with an invalid date of birth,
	 * excluding anyone over 120 years old
	 */
    /**** Denominator: any active patient  ****/    DROP TABLE IF EXISTS denominator;    CREATE TEMP TABLE denominator AS    SELECT         p.id::bigint    FROM universal.patient as p    WHERE        -- Active patient        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))        -- Clinic patient or no clinic        AND 			(p_clinic_reference = ''			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))        -- Practitioner's patient or no practitioner        AND 			(p_practitioner_msp = ''			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));            /**** Numerator: over 120 years old or missing birth date ****/    v_numerator := ARRAY(
    
		With effectiveBirthDates as (
			SELECT
				ea.date_value as birth_date,
				e.patient_id,
				RANK() OVER(PARTITION BY e.patient_id ORDER BY ea.emr_effective_date DESC, ea.id DESC, s.effective_date DESC, s.id DESC) as rank
			FROM universal.entry_attribute as ea				
			JOIN universal.entry as e
				ON ea.entry_id = e.id
			JOIN universal.state as s
				ON s.record_id = ea.entry_id
				AND s.record_type = 'entry'
				AND s.effective_date <= p_effective_date
			WHERE 
				-- Valid birth date prior to the effective date
				ea.attribute_id = 5.001
				AND ea.emr_effective_date <= p_effective_date
				-- Clinic patient or no clinic
				AND 
					(p_clinic_reference = ''
					OR e.patient_id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))
				-- Practitioner's patient or no practitioner
				AND 
					(p_practitioner_msp = ''
					OR	e.patient_id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date))))
		SELECT
			d.id as patient_id
		FROM denominator as d	-- active patients
		LEFT OUTER JOIN effectiveBirthDates as ebd
			ON d.id = ebd.patient_id
		WHERE 
			ebd.birth_date IS NULL 	-- missing birthdates
			OR (					-- older than 120 years
				ebd.rank = 1
				AND date_part('year', age(p_effective_date, ebd.birth_date)) > 120				
			));                v_denominator := ARRAY(SELECT id from denominator);                END  $$;
ALTER FUNCTION indicator.hdc_0834(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0836(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0836(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$DECLARE v_active_state text;BEGIN
	/**     * Query Title: HDC-0836_DQ-CodedMedications     * Query Type:  Ratio     * Description: % of medication entries that are coded     */
    /** Active State Regex Expression **/    SELECT text_pattern    INTO v_active_state    FROM concept.code_mapping    WHERE concept_key = 'active state'    LIMIT 1; 	/**** Denominator: Total medication count  ****/    v_denominator := ARRAY(        -- Ensure entry state is active
		WITH activeState as (            SELECT                 e.id as entry_id,                e.patient_id,                s.state,                RANK() OVER(PARTITION BY e.id ORDER BY s.effective_date DESC, s.id DESC) as rank            FROM universal.entry as e            JOIN universal.state as s                ON e.id = s.record_id                 AND s.record_type = 'entry'                AND s.effective_date <= p_effective_date)        SELECT            s.entry_id        FROM activeState as s        WHERE                    -- The current entry state should be active            s.rank = 1                        AND s.state ~* v_active_state                        -- Clinic patient or no clinic            AND (p_clinic_reference = ''                OR s.patient_id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))            -- Practitioner's patient or no practitioner            AND                 (p_practitioner_msp = ''                OR	s.patient_id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)))            -- Had a prescription within last year            AND s.entry_id IN (SELECT entry_id FROM concept.prescription_count((p_effective_date - INTERVAL '1 year')::date, p_effective_date)));
			            /**** Numerator: Total coded medication count ****/    v_numerator := ARRAY(        WITH coded as (            SELECT                ea.entry_id,                RANK() OVER(PARTITION BY ea.entry_id ORDER BY ea.emr_effective_date DESC, ea.id DESC) as rank            FROM universal.entry_attribute as ea            WHERE                ea.attribute_id = 12.001                AND ea.emr_effective_date <= p_effective_date        )
        SELECT             d.entry_id        FROM coded as d        WHERE NOT EXISTS (            SELECT entry_id            FROM coded            WHERE rank = 1        ));          END  $$;
ALTER FUNCTION indicator.hdc_0836(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0837(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0837(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$BEGIN
	/**
	 * Query Title: HDC-0837 DQ-PrescriptionFrequency
	 * Query Type:  Ratio
	 */
 	/**** Denominator: total encounters in the last year  ****/    v_denominator := ARRAY(
		SELECT 			e.id		FROM universal.entry as e		WHERE						-- Clinic patient or no clinic				(p_clinic_reference = ''				OR e.patient_id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))			-- Practitioner's patient or no practitioner			AND 				(p_practitioner_msp = ''				OR	e.patient_id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)))			-- Had an encounter within last year
			AND e.id IN (SELECT entry_id FROM concept.encounters((p_effective_date - INTERVAL '1 year')::date, p_effective_date)));
			            /**** Numerator: total prescriptions in the last year ****/    v_numerator := ARRAY(
		SELECT 
			e.id
		FROM universal.entry as e
		WHERE
			
			-- Clinic patient or no clinic
				(p_clinic_reference = ''
				OR e.patient_id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))
			-- Practitioner's patient or no practitioner
			AND 
				(p_practitioner_msp = ''
				OR	e.patient_id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)))
			-- Had a prescription within last year
			AND e.id IN (SELECT entry_id FROM concept.prescription_count((p_effective_date - INTERVAL '1 year')::date, p_effective_date)));          END  $$;
ALTER FUNCTION indicator.hdc_0837(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0838(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0838(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$BEGIN
	/**     * Query Title: HDC-0838 DQ No Meds     * Query Type:  Ratio     */
 	/**** Denominator: any active patient  ****/    DROP TABLE IF EXISTS denominator;    CREATE TEMP TABLE denominator AS    SELECT         p.id::bigint    FROM universal.patient as p    WHERE        -- Active patient        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))        -- Clinic patient or no clinic        AND 			(p_clinic_reference = ''			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))        -- Practitioner's patient or no practitioner        AND 			(p_practitioner_msp = ''			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));
			            /**** Numerator: no active medications ****/    v_numerator := ARRAY(
		SELECT             d.id        FROM denominator as d        WHERE d.id NOT IN (SELECT patient_id FROM concept.prescription_active(null, p_effective_date)));          END  $$;
ALTER FUNCTION indicator.hdc_0838(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0919(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0919(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$BEGIN
	/**
	 * Query Title: HDC-0919 Hypertension & BP in last yr
	 * Query Type:  Ratio
	 * Description: Active patients with hypertension (based on problem list) 
	 * who have a blood pressure measurement documented within the past 12 months
	 */
	/**** Denominator  ****/    DROP TABLE IF EXISTS denominator;    CREATE TEMP TABLE denominator AS    SELECT         p.id::bigint    FROM universal.patient as p    WHERE        -- Active patient        p.id IN (SELECT patient_id FROM concept.patient(p_effective_date))        -- Clinic patient or no clinic        AND 			(p_clinic_reference = ''			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))        -- Practitioner's patient or no practitioner        AND 			(p_practitioner_msp = ''			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)))
		-- Has hypertension
		AND p.id IN (SELECT patient_id FROM concept.concept('hypertension', p_effective_date));            /**** Numerator ****/    v_numerator := ARRAY(        SELECT id        FROM denominator d        WHERE d.id IN (			-- Has had a blood pressure in the last 12 months			SELECT patient_id FROM concept.observation('blood pressure', (p_effective_date - INTERVAL '1 year')::date, p_effective_date, NULL, NULL)        ));                v_denominator := ARRAY(SELECT id from denominator);          END  $$;
ALTER FUNCTION indicator.hdc_0919(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0919_v2(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0919_v2(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$BEGIN	/**** Denominator  ****/    DROP TABLE IF EXISTS denominator;    CREATE TEMP TABLE denominator AS    SELECT 
		p.patient_id        -- Active patient    FROM concept.patient(p_effective_date) as p	JOIN concept.clinic(p_clinic_reference, p_effective_date) as c
		ON p_clinic_reference = '' OR p.patient_id = c.patient_id
	JOIN concept.practitioner(p_practitioner_MSP, p_effective_date) as pr
		ON p_practitioner_MSP = '' OR p.patient_id = pr.patient_id
	JOIN concept.concept('hypertension', p_effective_date) as ht
		ON p.patient_id = ht.patient_id;            /**** Numerator ****/    v_numerator := ARRAY(        SELECT d.patient_id        FROM denominator d        JOIN concept.observation('blood pressure', (p_effective_date - INTERVAL '1 year')::date, p_effective_date, NULL, NULL) as bp
			ON d.patient_id = bp.patient_id);                v_denominator := ARRAY(SELECT patient_id from denominator);          END  $$;
ALTER FUNCTION indicator.hdc_0919_v2(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0954(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0954(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     
BEGIN
	/**
	* Query Title: HDC-0954
	* Query Type:  Ratio
	* Initiative:  Population Health
	* Description: Percentage of adults with chronic kidney disease
	*/
	
    /**** Denominator  ****/
    DROP TABLE IF EXISTS denominator;
    CREATE TEMP TABLE denominator AS
    SELECT 
        p.id::bigint
    FROM universal.patient as p
    WHERE
        -- Active patient
        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))
        -- Clinic patient or no clinic
        AND 
			(p_clinic_reference = ''
			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))
        -- Practitioner's patient or no practitioner
        AND 
			(p_practitioner_msp = ''
			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));
        
    /**** Numerator ****/
    v_numerator := ARRAY(
        SELECT id
        FROM denominator d
        WHERE d.id IN (SELECT patient_id FROM concept.concept('chronic kidney disease', p_effective_date)));
            
    v_denominator := ARRAY(SELECT id from denominator);        
        
END  
$$;
ALTER FUNCTION indicator.hdc_0954(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0955(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0955(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     
BEGIN
	/**
    * Query Title: HDC-0955
    * Query Type:  Ratio
    * Initiative:  Population Health
    * Description: Percentage of adults with congestive heart failure
    */
	
    /**** Denominator  ****/
    DROP TABLE IF EXISTS denominator;
    CREATE TEMP TABLE denominator AS
    SELECT 
        p.id::bigint
    FROM universal.patient as p
    WHERE
        -- Active patient
        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))
        -- Clinic patient or no clinic
        AND 
			(p_clinic_reference = ''
			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))
        -- Practitioner's patient or no practitioner
        AND 
			(p_practitioner_msp = ''
			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));
        
    /**** Numerator ****/
    v_numerator := ARRAY(
        SELECT id
        FROM denominator d
        WHERE d.id IN (SELECT patient_id FROM concept.concept('congestive heart failure', p_effective_date)));
            
    v_denominator := ARRAY(SELECT id from denominator);        
        
END  
$$;
ALTER FUNCTION indicator.hdc_0955(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0958(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0958(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     
BEGIN
    /**
    * Query Title: HDC-0958
    * Query Type:  Ratio
    * Initiative:  Population Health
    * Description: Percentage of adults with chronic obstructive pulminary disease
    */
	
    /**** Denominator  ****/
    DROP TABLE IF EXISTS denominator;
    CREATE TEMP TABLE denominator AS
    SELECT 
        p.id::bigint
    FROM universal.patient as p
    WHERE
        -- Active patient
        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))
        -- Clinic patient or no clinic
        AND 
			(p_clinic_reference = ''
			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))
        -- Practitioner's patient or no practitioner
        AND 
			(p_practitioner_msp = ''
			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));
        
    /**** Numerator ****/
    v_numerator := ARRAY(
        SELECT id
        FROM denominator d
        WHERE d.id IN (SELECT patient_id FROM concept.concept('copd', p_effective_date)));
            
    v_denominator := ARRAY(SELECT id from denominator);        
        
END  
$$;
ALTER FUNCTION indicator.hdc_0958(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0959(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0959(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     
BEGIN
	/**
    * Query Title: HDC-0959
    * Query Type:  Ratio
    * Initiative:  Population Health
    * Description: Percentage of adults with depression
    */
	
    /**** Denominator  ****/
    DROP TABLE IF EXISTS denominator;
    CREATE TEMP TABLE denominator AS
    SELECT 
        p.id::bigint
    FROM universal.patient as p
    WHERE
        -- Active patient
        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))
        -- Clinic patient or no clinic
        AND 
			(p_clinic_reference = ''
			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))
        -- Practitioner's patient or no practitioner
        AND 
			(p_practitioner_msp = ''
			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));
        
    /**** Numerator ****/
    v_numerator := ARRAY(
        SELECT id
        FROM denominator d
        WHERE d.id IN (SELECT patient_id FROM concept.concept('depression', p_effective_date)));
            
    v_denominator := ARRAY(SELECT id from denominator);        
        
END  
$$;
ALTER FUNCTION indicator.hdc_0959(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0960(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0960(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     
BEGIN
	/**
     * Query Title: HDC-0960 
     * Query Type: Ratio 
     * Initiative: Population Health
     * Description: Percentage of patients with diabetes
     */
	
    /**** Denominator  ****/
    DROP TABLE IF EXISTS denominator;
    CREATE TEMP TABLE denominator AS
    SELECT 
        p.id::bigint
    FROM universal.patient as p
    WHERE
        -- Active patient
        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))
        -- Clinic patient or no clinic
        AND 
			(p_clinic_reference = ''
			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))
        -- Practitioner's patient or no practitioner
        AND 
			(p_practitioner_msp = ''
			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));
        
    /**** Numerator ****/
    v_numerator := ARRAY(
        SELECT id
        FROM denominator d
        WHERE d.id IN (SELECT patient_id FROM concept.concept('diabetes', p_effective_date)));
            
    v_denominator := ARRAY(SELECT id from denominator);        
        
END  
$$;
ALTER FUNCTION indicator.hdc_0960(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_0962(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_0962(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     
BEGIN
	/**
    * Query Title: HDC-0962
    * Query Type:  Ratio
    * Initiative:  Population Health
    * Description: Percentage of adults with hypertension
    */
	
    /**** Denominator  ****/
    DROP TABLE IF EXISTS denominator;
    CREATE TEMP TABLE denominator AS
    SELECT 
        p.id::bigint
    FROM universal.patient as p
    WHERE
        -- Active patient
        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))
        -- Clinic patient or no clinic
        AND 
			(p_clinic_reference = ''
			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))
        -- Practitioner's patient or no practitioner
        AND 
			(p_practitioner_msp = ''
			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));
        
    /**** Numerator ****/
    v_numerator := ARRAY(
        SELECT id
        FROM denominator d
        WHERE d.id IN (SELECT patient_id FROM concept.concept('hypertension', p_effective_date)));
            
    v_denominator := ARRAY(SELECT id from denominator);        
        
END  
$$;
ALTER FUNCTION indicator.hdc_0962(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_1134(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_1134(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$BEGIN
	/**
	 * Query Title: HDC-1134 INR Monitoring
	 * Query Type:  Ratio
	 * Description: This metric shows the percentage of active patients with an active warfarin medication who have NOT had an INR result in the last month.
	 */
	/**** Denominator  ****/    DROP TABLE IF EXISTS denominator;    CREATE TEMP TABLE denominator AS    SELECT         p.id::bigint    FROM universal.patient as p    WHERE        -- Active patient        p.id IN (SELECT patient_id FROM concept.patient(p_effective_date))        -- Clinic patient or no clinic        AND 			(p_clinic_reference = ''			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))        -- Practitioner's patient or no practitioner        AND 			(p_practitioner_msp = ''			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)))
		-- On warfarin medication
		AND p.id IN (SELECT patient_id FROM concept.prescription_active('warfarin', p_effective_date));            /**** Numerator ****/    v_numerator := ARRAY(        SELECT id        FROM denominator d        WHERE d.id NOT IN (			-- Has NOT had an INR observation in the last month (assumed to 30 days)			SELECT patient_id FROM concept.observation('INR', (p_effective_date - INTERVAL '30 days')::date, p_effective_date, NULL, NULL)        ));                v_denominator := ARRAY(SELECT id from denominator);          END  $$;
ALTER FUNCTION indicator.hdc_1134(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_1135_v1(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_1135_v1(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$DECLARE v_active integer[];          -- Active patientsDECLARE v_diabetics integer[];       -- Diabetic patientsDECLARE v_clinic integer[];          -- Patients in specified clinicDECLARE v_practitioner integer[];    -- Patients for specified practitionerDECLARE v_time timestamp;     BEGIN    v_time := (SELECT timeofday());        RAISE NOTICE 'Starting query: %' , v_time;    -- All active patients    v_active := ARRAY(        SELECT patient_id        FROM concept.patient(p_effective_date)    );    -- All diabetic patients    v_diabetics := ARRAY(        SELECT patient_id        FROM concept.concept('diabetes', p_effective_date)     );    -- Patients in specified clinic    v_clinic := ARRAY(        SELECT patient_id        FROM concept.clinic(p_clinic_reference, p_effective_date)    );    -- Patients for a specified practitioner    v_practitioner := ARRAY(        SELECT patient_id        FROM concept.practitioner(p_practitioner_MSP, p_effective_date)    );        /**** Find numerator patients ****/    v_numerator := ARRAY(        SELECT p.id        FROM universal.patient as p        WHERE             -- Is active patient            p.id = ANY(v_active)            -- Has active condition of diabetes            and p.id = ANY(v_diabetics)            -- Patient's primary practitioner or no practitioner passed in            AND (                p_practitioner_MSP IS NULL                OR                 p.id = ANY(v_practitioner)            )            -- Patient is a member of the clinic or no clinic passed in            AND (                p.id = ANY(v_practitioner)            )            -- Has H1AC at any time less than 7.1            AND p.id IN (SELECT * FROM concept.observation(                'hemoglobinA1C', '1900/1/1'::date, current_date, 0, 7.1            ))      );    /**** Find denominator patients ****/    v_denominator := ARRAY(        SELECT p.id        FROM universal.patient as p        WHERE            -- Is active patient            p.id = ANY(v_active)            -- Has active condition of diabetes            and p.id = ANY(v_diabetics)            -- Patient's primary practitioner or no practitioner passed in            AND (                p_practitioner_MSP IS NULL                OR                 p.id = ANY(v_practitioner)            )            -- Patient is a member of the clinic or no clinic passed in            AND (                p.id = ANY(v_practitioner)            )       );               END  $$;
ALTER FUNCTION indicator.hdc_1135_v1(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_1135a(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_1135a(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$     BEGIN	/**
	 * Query Title: HDC-1135A_LastLab-A1C<7point1wDiabetes
	 * Query Type:  Ratio
	 */
    /**** Denominator  ****/    DROP TABLE IF EXISTS denominator;    CREATE TEMP TABLE denominator AS    SELECT         p.id::bigint    FROM universal.patient as p    WHERE        -- Active patient        p.id IN (SELECT patient_id FROM concept.patient_active(p_effective_date))        -- Diabetic patient        AND p.id IN (SELECT patient_id FROM concept.concept('diabetes', p_effective_date))        -- Clinic patient or no clinic        AND 			(p_clinic_reference = ''			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))        -- Practitioner's patient or no practitioner        AND 			(p_practitioner_msp = ''			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));            /**** Numerator ****/    v_numerator := ARRAY(        SELECT id        FROM denominator d        WHERE d.id IN (SELECT concept.observation('hemoglobinA1C', '1900/1/1'::date, p_effective_date, 0, 7.1)));                v_denominator := ARRAY(SELECT id from denominator);                END  $$;
ALTER FUNCTION indicator.hdc_1135a(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
--
-- Name: hdc_1996(text, text, date); Type: FUNCTION; Schema: indicator; Owner: postgres
--
CREATE FUNCTION hdc_1996(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$BEGIN
	/**
	 * Query Title: HDC-1996 Antipsychotic Use
	 * Query Type:  Ratio
	 * Description: This metric shows the percentage of active patients that have 
	 * an active medication for an antipsychotic.
	 */
	/**** Denominator  ****/    DROP TABLE IF EXISTS denominator;    CREATE TEMP TABLE denominator AS    SELECT         p.id::bigint    FROM universal.patient as p    WHERE        -- Active patient        p.id IN (SELECT patient_id FROM concept.patient(p_effective_date))        -- Clinic patient or no clinic        AND 			(p_clinic_reference = ''			OR p.id IN (SELECT patient_id FROM concept.clinic(p_clinic_reference, p_effective_date)))        -- Practitioner's patient or no practitioner        AND 			(p_practitioner_msp = ''			OR	p.id IN (SELECT patient_id FROM concept.practitioner(p_practitioner_MSP, p_effective_date)));            /**** Numerator ****/    v_numerator := ARRAY(        SELECT id        FROM denominator d        WHERE d.id IN (			-- Taking antipsychotic medication (prescription status is active)			SELECT patient_id FROM concept.concept('antipsychotic', p_effective_date)        ));                v_denominator := ARRAY(SELECT id from denominator);          END  $$;
ALTER FUNCTION indicator.hdc_1996(p_clinic_reference text, p_practitioner_msp text, p_effective_date date, OUT v_numerator integer[], OUT v_denominator integer[]) OWNER TO postgres;
SET search_path = test, pg_catalog;
--
-- Name: blow_it_away(); Type: FUNCTION; Schema: test; Owner: postgres
--
CREATE FUNCTION blow_it_away() RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
	BEGIN
	/*
		Author: 	Daniel Egli
		Created: 	April 21, 2017
		Description:
			Truncates all data tables in order to have a fresh empty testing database
		Success:
			Returns true
	*/
		-- Empty tables
        DELETE FROM universal.state;
        DELETE FROM universal.entry_attribute;
        DELETE FROM universal.entry;
        DELETE FROM universal.entry;
        DELETE FROM universal.patient;
        DELETE FROM concept.code_mapping;
        ALTER SEQUENCE concept.code_mapping_new_id_seq RESTART WITH 1;        
        DELETE FROM test.cleanup;
        DELETE FROM test.tests;
    
        -- Add concepts back to code mapping table
        INSERT INTO concept.code_mapping (attribute_id, concept_key, code_system, code_pattern, text_pattern) VALUES
        (NULL, 'active state', NULL, NULL, '.*active.*|AC|A'),
        (5.002, 'female', 'OSCAR', '.*F.*', NULL),
        (5.002, 'male', 'OSCAR', '^(?!.*(F)).*M.*$', NULL),
        (9.001, 'blood pressure', 'OSCAR', 'BP', 'Blood Pressure'),
        (9.001, 'hemoglobinA1C', 'pCLOCD', '4548-4', NULL),
        (9.001, 'hemoglobinA1C', 'OSCAR', NULL, '.*A1C.*'),
        (9.001, 'INR', 'OSCAR', 'INR', NULL),
        (9.001, 'unspecified gender', 'OSCAR', 'U', NULL),
        (11.001, 'antipsychotic', 'ATC', 'N05A', NULL),
        (11.002, 'warfarin', 'ATC', '^B01AA03.*', NULL),
        (11.002, 'digoxin', 'ATC', '^C01AA', NULL),
        (12.002, 'antipsychotic', 'ATC', 'N05A', NULL),
        (12.002, 'warfarin', 'ATC', '^B01AA03.*', NULL),
        (12.002, 'digoxin', 'ATC', '^C01AA', NULL),
        (14.001, 'chronic kidney disease', 'ICD9', '^581|^582|^583|^585|^587|^588', NULL),
        (14.001, 'congestive heart failure', 'ICD9', '^428', NULL),
        (14.001, 'depression', 'ICD9', '311',NULL),
        (14.001, 'depression', 'SNOMEDCT', '35489007',NULL),
        (14.001, 'chronic pain', 'ICD9', '^338',NULL),
        (14.001, 'copd', 'ICD9', '496|^491|^492|^494',NULL),
        (14.001, 'copd', 'SNOMEDCT', '13645005',NULL),
        (14.001, 'hypertension', 'ICD9', '^401',NULL),
        (14.001, 'hypertension', 'SNOMEDCT', '38341003',NULL),
        (14.001, 'diabetes', 'ICD9', '^250', NULL),
        (14.001, 'diabetes', 'SNOMEDCT', '73211009|44054006|46635009',NULL),
        (14.001, 'impaired renal function', 'ICD9', '586', NULL),
        (11.002, 'pneumococcal', 'whoATC', 'J07AL02', NULL),
        (11.002, 'pneumococcal', 'SNOMEDCT', '12866006|394678003', NULL),
        (15.001, 'colon cancer', 'pCLOCD', '14563-1|14564-9|19762-4|58453-2', NULL),
        (15.001, 'colonoscopy', 'pCLOCD', '67166-9|67222-0|67221-2|67220-4', NULL),
        (15.001, 'glucose fasting', 'pCLOCD', '14771-0', NULL);        
        
        RETURN TRUE;
	END
$_$;
ALTER FUNCTION test.blow_it_away() OWNER TO postgres;
--
-- Name: concept_concept(); Type: FUNCTION; Schema: test; Owner: postgres
--
CREATE FUNCTION concept_concept() RETURNS void
    LANGUAGE plpgsql
    AS $$     
DECLARE v_entry_id integer;
DECLARE v_patient_id integer; 
DECLARE v_clinic_id integer;
BEGIN
	/**             TEST DATA ENTRY                 **/
    -- test concept concept
    INSERT INTO concept.code_mapping(attribute_id, concept_key, code_system, code_pattern, text_pattern)
    VALUES (12.002, 'test concept', 'ATC', '^ZZZ', null);
    INSERT INTO concept.code_mapping(attribute_id, concept_key, code_system, code_pattern, text_pattern)
    VALUES (12.002, 'test concept', 'ATC', '^XXX', null);
    -- Test clinic
    IF NOT EXISTS(SELECT 1 FROM universal.clinic) THEN 
        INSERT INTO universal.clinic(name, hdc_reference, emr_id)
        VALUES ('Maya Clinic', 'MC', '1234');
    END IF;
    SELECT MIN(id) INTO v_clinic_id FROM universal.clinic;
    -- Test patient
    INSERT INTO universal.patient(clinic_id, emr_id)
    VALUES(v_clinic_id, 999999)
    RETURNING id INTO v_patient_id;
    -- Test entry
    INSERT INTO universal.entry (patient_id, emr_table, emr_id)
    VALUES(v_patient_id, 'drugs', 999999)
    RETURNING id INTO v_entry_id;
    -- Test attribute values
    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date)
    VALUES(v_entry_id, 12.002, 'ATC', 'AAA9520', 'Should not match [test concept] concept', '2016-01-01');
    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date)
    VALUES(v_entry_id, 12.002, 'ATC', 'ZZZ9520', 'Should match [test concept] concept', '2017-03-01');
    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date)
    VALUES(v_entry_id, 12.002, 'ATC', 'XXX9520', 'Should match [test concept] concept', '2017-02-01');
    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date)
    VALUES(v_entry_id, 12.002, 'XCLAS', 'ZZZ9520', 'Should not match [test concept] concept', '2017-01-01');
    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date)
    VALUES(v_entry_id, 12.002, 'XCLAS', 'CC9520', 'Should not match [test concept] concept', '2017-03-04');
    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date)
    VALUES(v_entry_id, 12.002, 'ATC', 'XXX9520', 'Should match [test concept] concept', '2017-04-01');
    -- Test state
    INSERT INTO universal.state(record_type, record_id, effective_date, state)
    VALUES('entry', v_entry_id, '2016-01-01', 'actiVE');   
    INSERT INTO universal.state(record_type, record_id, effective_date, state)
    VALUES('entry', v_entry_id, '2017-04-01', 'deleted'); 
    INSERT INTO universal.state(record_type, record_id, effective_date, state)
    VALUES('entry', v_entry_id, '2017-05-01', 'actiVE');
    /**             TEST CALLS                      **/
    
    INSERT INTO test.tests(selects, schema, function, parameters, expectation, message) VALUES
    ('{patient_id}', 'concept', 'concept', '{test concept, 2015-01-02}', 'NULL', 'Effective date prior to entry effective date'),
    ('{patient_id}', 'concept', 'concept', '{test concept, 2016-01-02}', 'NULL', 'Most recent attribute has wrong code_value value'),
    ('{patient_id}', 'concept', 'concept', '{test concept, 2017-01-02}', 'NULL', 'Most recent attribute has wrong code_system value'),
    ('{patient_id}', 'concept', 'concept', '{test concept, 2017-02-02}', 'VALUE', 'Most recent attribute should match'),
    ('{patient_id}', 'concept', 'concept', '{test concept, 2017-03-02}', 'VALUE', 'Two historical attributes including most recent one that should match'),
    ('{patient_id}', 'concept', 'concept', '{test concept, 2017-03-05}', 'NULL', 'Most recent attribute does not match'),
    ('{patient_id}', 'concept', 'concept', '{test concept, 2017-04-02}', 'NULL', 'Most recent attribute matches but state is not active'),
    ('{patient_id}', 'concept', 'concept', '{test concept, 2017-06-02}', 'VALUE', 'Historical state is deleted but most recent is active');
    
   
    /**             CLEANUP TESTS                   **/
    INSERT INTO test.cleanup(entry_id, patient_id, concept_key, text_pattern) VALUES
    (v_entry_id, v_patient_id, 'test concept', null);
    
END  
$$;
ALTER FUNCTION test.concept_concept() OWNER TO postgres;
--
-- Name: concept_patient_age(); Type: FUNCTION; Schema: test; Owner: postgres
--
CREATE FUNCTION concept_patient_age() RETURNS void
    LANGUAGE plpgsql
    AS $_$     DECLARE v_entry_id integer;DECLARE v_patient_id integer; 
DECLARE v_clinic_id integer;BEGIN	/**             TEST DATA ENTRY                 **/    -- Test clinic
    IF NOT EXISTS(SELECT 1 FROM universal.clinic) THEN 
        INSERT INTO universal.clinic(name, hdc_reference, emr_id)
        VALUES ('Maya Clinic', 'MC', '1234');
    END IF;
    SELECT MIN(id) INTO v_clinic_id FROM universal.clinic;    -- Test patient    INSERT INTO universal.patient(clinic_id, emr_id)    VALUES(v_clinic_id, 100000001)    RETURNING id INTO v_patient_id;        INSERT INTO universal.entry (patient_id, emr_table, emr_id) VALUES(v_patient_id, 'demographic', 10000001) RETURNING id INTO v_entry_id;    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 5.001, '1987-10-21', '2016-01-01');  -- 1987 birthdate    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 5.001, '1997-10-21', '2016-02-01');  -- 1997 birthdate    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 5.001, '2007-10-21', '2016-03-01');  -- 2007 birthdate        INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2016-01-15', 'test actiVE');        -- Demographic record valid starting Feb 1    INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2016-02-15', 'hold');               -- Demographic hold Feb 1    INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2016-03-15', ' test actiVE');       -- Demographic active on Feb 10    -- Test active state concept    INSERT INTO concept.code_mapping(concept_key, text_pattern) VALUES ('active state', '.*actIve.*|AC');    INSERT INTO concept.code_mapping(attribute_id, concept_key, code_system, code_pattern) VALUES (5.002, 'female', 'OSCAR', '.*F.*');    INSERT INTO concept.code_mapping(attribute_id, concept_key, code_system, code_pattern) VALUES (5.002, 'male', 'OSCAR', '^(?!.*(F)).*M.*$');    /**             TEST CALLS                      **/        INSERT INTO test.tests(selects, schema, function, parameters, expectation, message) VALUES    ('{patient_id}', 'concept', 'patient_age', '{2010-12-01, 0, 120}', 'NULL', 'Prior to all effective dates. Should return nothing'),    ('{patient_id}', 'concept', 'patient_age', '{2016-01-02, 50, 100}', 'NULL', 'Age interval too high. Should return nothing'),    ('{patient_id}', 'concept', 'patient_age', '{2016-01-10, 25, 30}', 'NULL', 'Valid entry and interval but not active. Should return nothing'),    ('{patient_id}', 'concept', 'patient_age', '{2016-01-20, 25, 30}', 'VALUE', 'Valid entry and interval. Should return a patient'),    ('{patient_id}', 'concept', 'patient_age', '{2016-10-20, 9, 9}', 'NULL', 'One day short of the interval. Should return nothing'),    ('{patient_id}', 'concept', 'patient_age', '{2016-10-21, 9, 9}', 'VALUE', 'Exactly on the interval. Should return a patient'),    ('{patient_id}', 'concept', 'patient_age', '{2016-10-22, 9, 9}', 'VALUE', 'One day over year range. Should return a patient'),    ('{patient_id}', 'concept', 'patient_age', '{2016-02-20, 0, 100}', 'NULL', 'Entry status on hold. Should return nothing');            /**             CLEANUP TESTS                   **/        INSERT INTO test.cleanup(entry_id, patient_id, concept_key, text_pattern) VALUES    (v_entry_id, v_patient_id, 'test female', null),    (null, null, 'test male', '.*tESt actIve.*');            END  $_$;
ALTER FUNCTION test.concept_patient_age() OWNER TO postgres;
--
-- Name: concept_prescription_active(); Type: FUNCTION; Schema: test; Owner: postgres
--
CREATE FUNCTION concept_prescription_active() RETURNS TABLE(func text, description text)
    LANGUAGE plpgsql
    AS $$     DECLARE v_entry_id integer;DECLARE v_patient_id integer; 
DECLARE v_clinic_id integer;BEGIN	/**             TEST DATA ENTRY                 **/    -- Test clinic
    IF NOT EXISTS(SELECT 1 FROM universal.clinic) THEN 
        INSERT INTO universal.clinic(name, hdc_reference, emr_id)
        VALUES ('Maya Clinic', 'MC', '1234');
    END IF;
    SELECT MIN(id) INTO v_clinic_id FROM universal.clinic;
    -- Test patient    INSERT INTO universal.patient(clinic_id, emr_id)    VALUES(v_clinic_id, 100000001)    RETURNING id INTO v_patient_id;        -- Drug 1:    Jan 1, 2016 - March 1, 2016    INSERT INTO universal.entry (patient_id, emr_table, emr_id) VALUES(v_patient_id, 'drugs', 10000001) RETURNING id INTO v_entry_id;    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date) VALUES(v_entry_id, 12.001, 'TST', 'ZZZ123', 'Med 1', '2016-01-01');  -- Taking med ZZZ123    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date) VALUES(v_entry_id, 12.001, 'TST', 'AAA123', 'Med 1', '2016-01-15');  -- Changed to med AAA123    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date) VALUES(v_entry_id, 12.001, 'TST', 'ZZZ123', 'Med 1', '2016-02-01');  -- Changed back to med ZZZ123        INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.008, '2016-01-01', '2016-01-01');   -- Start date set for Jan 1    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.008, '2016-01-10', '2016-01-01');   -- Start date immedietely changed to Jan 10    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.009, '2016-03-01', '2016-01-01');   -- Stop date of March 1    INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2016-01-03', 'test actiVE');    -- Medication record valid starting Jan 3    INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2016-02-05', 'hold');           -- Medication hold Feb 1    INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2016-02-10', 'actiVE');         -- Medication active on Feb 10    -- test prescription active concept    INSERT INTO concept.code_mapping(attribute_id, concept_key, code_system, code_pattern)    VALUES(12.001, 'test prescription active', 'TST', '^ZZZ');    -- Test active state concept    INSERT INTO concept.code_mapping(concept_key, text_pattern)    VALUES ('active state', '.*tESt actIve.*');    /**             TEST CALLS                      **/        INSERT INTO test.tests(selects, schema, function, parameters, expectation, message) VALUES    ('{patient_id}', 'concept', 'prescription_active', '{test prescription active, 2015-12-01}', 'NULL', 'Taking med prior to any records. Should return nothing'),    ('{patient_id}', 'concept', 'prescription_active', '{test prescription active, 2016-01-02}', 'NULL', 'Before start date and med entry not active. Should return nothing.'),    ('{patient_id}', 'concept', 'prescription_active', '{test prescription active, 2016-01-04}', 'NULL', 'Med entry active but before changed start date. Should return nothing'),    ('{patient_id}', 'concept', 'prescription_active', '{test prescription active, 2016-01-11}', 'VALUE', 'Within dates and active.  Should return a patient'),    ('{patient_id}', 'concept', 'prescription_active', '{test prescription active, 2016-01-16}', 'NULL', 'Wrong medication type. Should return nothing.'),    ('{patient_id}', 'concept', 'prescription_active', '{test prescription active, 2016-02-02}', 'VALUE', 'Medication type changed to right med. Should return a patient.'),    ('{patient_id}', 'concept', 'prescription_active', '{test prescription active, 2016-02-06}', 'NULL', 'Entry status on hold. Should return nothing.'),    ('{patient_id}', 'concept', 'prescription_active', '{test prescription active, 2016-02-11}', 'VALUE', 'Entry status back to active. Should return a patient.'),    ('{patient_id}', 'concept', 'prescription_active', '{test prescription active, 2016-03-06}', 'NULL', 'After stop date. Should return nothing.');        /**             CLEANUP TESTS                   **/    INSERT INTO test.cleanup(entry_id, patient_id, concept_key, text_pattern) VALUES    (v_entry_id, null, null, null),    (null, v_patient_id, null, null),    (null, null, 'test prescription active', null),    (null, null, null, '.*tESt actIve.*');        END  $$;
ALTER FUNCTION test.concept_prescription_active() OWNER TO postgres;
--
-- Name: concept_prescription_minimum_meds(); Type: FUNCTION; Schema: test; Owner: postgres
--
CREATE FUNCTION concept_prescription_minimum_meds() RETURNS void
    LANGUAGE plpgsql
    AS $$     DECLARE v_entry_id integer;DECLARE v_patient_id integer; 
DECLARE v_clinic_id integer;BEGIN	/**             TEST DATA ENTRY                 **/    -- Test clinic
    IF NOT EXISTS(SELECT 1 FROM universal.clinic) THEN 
        INSERT INTO universal.clinic(name, hdc_reference, emr_id)
        VALUES ('Maya Clinic', 'MC', '1234');
    END IF;
    SELECT MIN(id) INTO v_clinic_id FROM universal.clinic;
    -- Test patient    INSERT INTO universal.patient(clinic_id, emr_id)    VALUES(v_clinic_id, 100000001)    RETURNING id INTO v_patient_id;        -- Drug 1:    Jan 1, 2016 - March 1, 2016    INSERT INTO universal.entry (patient_id, emr_table, emr_id) VALUES(v_patient_id, 'drugs', 10000001) RETURNING id INTO v_entry_id;    SELECT v_entry_id INTO v_entry_id;    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date) VALUES(v_entry_id, 12.001, 'DIN', '000001', 'Med 1', '2016-01-01');    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.008, '2016-01-01', '2016-01-01');    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.008, '2016-01-10', '2016-01-01');    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.009, '2017-03-01', '2016-01-01');    INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2016-02-01', 'test actiVE');       INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2017-01-01', 'deleted');     INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2017-05-01', 'test actiVE');
	INSERT INTO test.cleanup(entry_id, patient_id, concept_key, text_pattern) VALUES
    (v_entry_id, null, null, null);    -- Drug 2:    Jan 1, 2016 - March 1, 2016    INSERT INTO universal.entry (patient_id, emr_table, emr_id) VALUES(v_patient_id, 'drugs', 10000002) RETURNING id INTO v_entry_id;    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date) VALUES(v_entry_id, 12.001, 'DIN', '000002', 'Med 2', '2016-01-01');    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.008, '2016-01-01', '2016-01-01');    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.008, '2016-01-10', '2016-01-01');    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.009, '2017-03-01', '2016-01-01');    INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2015-01-01', 'test actiVE');       INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2017-01-01', 'deleted');     INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2017-05-01', 'test actiVE');
	INSERT INTO test.cleanup(entry_id, patient_id, concept_key, text_pattern) VALUES
    (v_entry_id, null, null, null);    -- Drug 3:    Jan 1, 2016 - March 1, 2016    INSERT INTO universal.entry (patient_id, emr_table, emr_id) VALUES(v_patient_id, 'drugs', 10000003) RETURNING id INTO v_entry_id;    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date) VALUES(v_entry_id, 12.001, 'DIN', '000003', 'Med 3', '2016-01-01');    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.008, '2016-01-01', '2016-01-01');    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.008, '2016-01-10', '2016-01-01');    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.009, '2017-03-01', '2016-01-01');    INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2015-01-01', 'test actiVE');       INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2017-01-01', 'deleted');     INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2017-05-01', 'test actiVE');
	INSERT INTO test.cleanup(entry_id, patient_id, concept_key, text_pattern) VALUES
    (v_entry_id, null, null, null);    -- Drug 4:    Jan 1, 2016 - March 1, 2016    INSERT INTO universal.entry (patient_id, emr_table, emr_id) VALUES(v_patient_id, 'drugs', 10000004) RETURNING id INTO v_entry_id;    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date) VALUES(v_entry_id, 12.001, 'DIN', '000004', 'Med 4', '2016-01-01');    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.008, '2016-01-01', '2016-01-01');    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.008, '2016-01-10', '2016-01-01');    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.009, '2017-03-01', '2016-01-01');    INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2015-01-01', 'test actiVE');       INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2017-01-01', 'deleted');     INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2017-05-01', 'test actiVE');
	INSERT INTO test.cleanup(entry_id, patient_id, concept_key, text_pattern) VALUES
    (v_entry_id, null, null, null);    -- Drug 5:    Jan 1, 2016 - March 1, 2016    INSERT INTO universal.entry (patient_id, emr_table, emr_id) VALUES(v_patient_id, 'drugs', 10000005) RETURNING id INTO v_entry_id;    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date) VALUES(v_entry_id, 12.001, 'DIN', '000005', 'Med 5', '2016-01-01');    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.008, '2016-01-01', '2016-01-01');    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.008, '2016-01-10', '2016-01-01');    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 12.009, '2017-03-01', '2016-01-01');    INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2015-01-01', 'test actiVE');       INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2017-01-01', 'deleted');     INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2017-05-01', 'test actiVE');    -- Test active state concept    INSERT INTO concept.code_mapping(concept_key, text_pattern)    VALUES ('active state', '.*tESt actIve.*');    /**             TEST CALLS                      **/        INSERT INTO test.tests(selects, schema, function, parameters, expectation, message) VALUES    ('{patient_id}', 'concept', 'prescription_minimum_meds', '{2016-02-01, 3}', 'VALUE', 'Test for simple 3 meds'),    ('{patient_id}', 'concept', 'prescription_minimum_meds', '{2016-01-02, 3}', 'NULL', 'Test for 3 meds before changed start date. Should return nothing'),    ('{patient_id}', 'concept', 'prescription_minimum_meds', '{2016-01-02, 8}', 'NULL', 'Test for 8 meds. Should find no patients'),    ('{patient_id}', 'concept', 'prescription_minimum_meds', '{2016-01-02, 5}', 'NULL', 'Test for exactly 5 meds in January 2016 (1 state inactive). Should return nothing'),    ('{patient_id}', 'concept', 'prescription_minimum_meds', '{2016-02-02, 5}', 'VALUE', 'Test for exactly 5 meds in February 2016 (0 state inactive). Should return a patient'),    ('{patient_id}', 'concept', 'prescription_minimum_meds', '{2017-05-01, 2}', 'NULL', 'Test for 2 meds past stop dates. Should return nothing'),    ('{patient_id}', 'concept', 'prescription_minimum_meds', '{2015-01-02, 2}', 'NULL', 'Test for 2 meds prior to start dates. Should return nothing'),    ('{patient_id}', 'concept', 'prescription_minimum_meds', '{2017-02-15, 2}', 'NULL', 'Med entries have "deleted" status. Should return nothing');    /**             CLEANUP TESTS                   **/    INSERT INTO test.cleanup(entry_id, patient_id, concept_key, text_pattern) VALUES    (v_entry_id, null, null, null),    (null, v_patient_id, null, null),    (null, null, null, '.*tESt actIve.*');        END  $$;
ALTER FUNCTION test.concept_prescription_minimum_meds() OWNER TO postgres;
--
-- Name: concept_procedure_in_date_range(); Type: FUNCTION; Schema: test; Owner: postgres
--
CREATE FUNCTION concept_procedure_in_date_range() RETURNS TABLE(func text, description text)
    LANGUAGE plpgsql
    AS $$     
DECLARE v_entry_id integer;
DECLARE v_patient_id integer; 
DECLARE v_clinic_id integer;
BEGIN
	/**             TEST DATA ENTRY                 **/
    -- Test clinic
    IF NOT EXISTS(SELECT 1 FROM universal.clinic) THEN 
        INSERT INTO universal.clinic(name, hdc_reference, emr_id)
        VALUES ('Maya Clinic', 'MC', '1234');
    END IF;
    SELECT MIN(id) INTO v_clinic_id FROM universal.clinic;
    -- Test patient
    INSERT INTO universal.patient(clinic_id, emr_id)
    VALUES(v_clinic_id, 100000001)
    RETURNING id INTO v_patient_id;
    
    -- Colon cancer screening procedure
    INSERT INTO universal.entry (patient_id, emr_table, emr_id) VALUES(v_patient_id, 'procudures', 10000001) RETURNING id INTO v_entry_id;
    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date) VALUES(v_entry_id, 15.001, 'TST', '14563-1', 'TEST - colon cancer screening', '2016-01-01');  -- Colon cancer screening
    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date) VALUES(v_entry_id, 15.001, 'TST', 'ZZZZZ-Z', 'TEST - colon cancer screening', '2016-01-15');  -- Changed to invalid procedure
    INSERT INTO universal.entry_attribute(entry_id, attribute_id, code_system, code_value, text_value, emr_effective_date) VALUES(v_entry_id, 15.001, 'TST', '14563-1', 'TEST - colon cancer screening', '2016-02-01');  -- Changed back colon cancer screening
    
    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 15.003, '2016-01-01', '2016-01-01');   -- Performed date set for Jan 1
    INSERT INTO universal.entry_attribute(entry_id, attribute_id, date_value, emr_effective_date) VALUES(v_entry_id, 15.003, '2016-01-10', '2016-01-01');   -- Performed date immedietely changed to Jan 10
    INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2016-01-03', 'test active');    -- Entry record valid starting Jan 3
    INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2016-02-05', 'hold');           -- Change entry to on hold
    INSERT INTO universal.state(record_type, record_id, effective_date, state) VALUES('entry', v_entry_id, '2016-02-10', 'test active');    -- Reset entry back to 'active'
    -- test concept
    INSERT INTO concept.code_mapping(attribute_id, concept_key, code_system, code_pattern)
    VALUES(15.001, 'test procedure in dates', 'TST', '14563-1');
    -- Test active state concept
    INSERT INTO concept.code_mapping(concept_key, text_pattern)
    VALUES ('active state', '.*test active.*');
    /**             TEST CALLS                      **/
    
    INSERT INTO test.tests(selects, schema, function, parameters, expectation, message) VALUES
    ('{patient_id}', 'concept', 'procedure_in_date_range', '{test procedure in dates, 2015-12-01, 2015-12-15}', 'NULL',  'Prior to entry recorded, should return nothing'),
    ('{patient_id}', 'concept', 'procedure_in_date_range', '{test procedure in dates, 2015-12-01, 2016-01-02}', 'NULL',  'Entry not valid yet at this point, should return nothing'),
    ('{patient_id}', 'concept', 'procedure_in_date_range', '{test procedure in dates, 2015-12-01, 2016-01-04}', 'NULL',  'Before performed procedure date, should return nothing'),
    ('{patient_id}', 'concept', 'procedure_in_date_range', '{test procedure in dates, 2015-12-01, 2016-01-11}', 'VALUE', 'Procedure performed and all active, should return a patient'),
    ('{patient_id}', 'concept', 'procedure_in_date_range', '{test procedure in dates, 2016-01-17, 2016-01-20}', 'NULL',  'Wrong procedure type, should return nothing'),
    ('{patient_id}', 'concept', 'procedure_in_date_range', '{test procedure in dates, 2015-12-05, 2016-01-20}', 'VALUE',  'First part of range is correct procedure type,should return a patient'),
    ('{patient_id}', 'concept', 'procedure_in_date_range', '{test procedure in dates, 2016-01-17, 2016-02-02}', 'NULL', 'Medication changed back to right type but performed date outside range, should return nothing'),
    ('{patient_id}', 'concept', 'procedure_in_date_range', '{test procedure in dates, 2016-02-07, 2016-02-09}', 'NULL',  'Entry status put on hold, should return nothing'),
    ('{patient_id}', 'concept', 'procedure_in_date_range', '{test procedure in dates, 2016-01-09, 2016-02-11}', 'VALUE', 'Entry status back to active during range. Should return a patient.');
    
    /**             CLEANUP TESTS                   **/
    --INSERT INTO test.cleanup(entry_id, patient_id, concept_key, text_pattern) VALUES
    --(v_entry_id, v_patient_id, 'test procedure in dates', '.*test active.*');
        
END  
$$;
ALTER FUNCTION test.concept_procedure_in_date_range() OWNER TO postgres;
--
-- Name: master(boolean); Type: FUNCTION; Schema: test; Owner: postgres
--
CREATE FUNCTION master(p_verbose boolean DEFAULT true) RETURNS TABLE(result text, description text)
    LANGUAGE plpgsql
    AS $$
	DECLARE
		tables CURSOR FOR
				SELECT  nspname, proname, *
				FROM    pg_catalog.pg_namespace n
				JOIN    pg_catalog.pg_proc p
				ON      pronamespace = n.oid
				LEFT OUTER JOIN 	pg_trigger t
				ON 		t.tgfoid = p.oid
				WHERE   nspname IN ('test')
						AND t.tgrelid is null
						AND proname <> 'master';
		v_state   TEXT;
		v_msg     TEXT;
		v_detail  TEXT;
		v_hint    TEXT;
		v_context TEXT;
		v_sql TEXT;
		temprow RECORD;
		v_output TEXT;
	BEGIN
	/*
		Author: 	Daniel Egli
		Created: 	April 18, 2017
		Description:
			Loops through all functions in the 'test' schema and calls them
		Parameters
			p_verbose: 	boolean value to indicate if extra messages such as 'Function success' should be printed. This clutters
						the true errors but provides more details.
		Success:
			Returns the calls that have failed
	*/
		FOR table_record IN tables LOOP
			
			BEGIN
				-- Try to execute the function. If successful, program flow continues, otherwise it jumps to the Exception block
				SELECT 'SELECT 1 FROM ' || table_record.nspname || '.' || table_record.proname || '()' INTO v_sql;
				EXECUTE v_sql;
				-- If p_verbose, then show successful function runs
				IF (p_verbose) THEN
						RAISE NOTICE '%(): test was run successfully', table_record.proname;
				END IF;
				-- Catch functions that create an error and handle it gracefully
				EXCEPTION WHEN OTHERS THEN
					GET STACKED DIAGNOSTICS
						v_state   = RETURNED_SQLSTATE,
						v_msg     = MESSAGE_TEXT,
						v_detail  = PG_EXCEPTION_DETAIL,
						v_hint    = PG_EXCEPTION_HINT,
						v_context = PG_EXCEPTION_CONTEXT;
					IF(v_msg not like '%violates foreign key%') THEN
						--Print the error message to the screen
						raise notice E'% got exception:
							state  : %
							message: %
							function: %',
							--detail : %
							--hint   : %
							--context: %',
							table_record.proname, v_state, v_msg, v_sql; --, v_detail, v_hint, v_context;
					END IF;
			END;
		END LOOP;
        -- Refresh materialized views once, loop through all tests, cleanup testing tables and output results
        IF (p_verbose) THEN
                RAISE NOTICE 'Starting to refresh materialized views...';
        END IF;
        REFRESH MATERIALIZED VIEW universal.mat_entry_attribute;
        REFRESH MATERIALIZED VIEW universal.mat_active_state;
        -- Loop through tests and execute each one
        FOR temprow IN
            SELECT 
                'SELECT ' || array_to_string(selects, ',') || ' FROM ' || schema || '.' || function || '(''' || array_to_string(parameters, ''',''') || ''')' as stmt
                ,function
                ,expectation
                ,message
                ,schema
            FROM test.tests 
        LOOP
            IF (p_verbose) THEN
                    RAISE NOTICE 'Executing %.%', temprow.schema, temprow.function;
            END IF;
            EXECUTE temprow.stmt INTO v_output;
            IF ((v_output IS NULL AND temprow.expectation = 'VALUE') OR (v_output IS NOT NULL and temprow.expectation = 'NULL')) THEN 
                RAISE NOTICE 
                '********** ERROR: % **********
                EXPECTING: %
                ERROR: %
                SQL: %
        *************************************', temprow.function, temprow.expectation, temprow.message, temprow.stmt;
            END IF;
        END LOOP;
        RAISE NOTICE 'Running cleanup script';
        -- Cleanup scripts
        /*DELETE FROM universal.state WHERE record_type = 'entry' AND record_id IN (SELECT entry_id FROM test.cleanup WHERE entry_id IS NOT NULL);
        DELETE FROM universal.entry_attribute WHERE entry_id IN (SELECT entry_id FROM test.cleanup WHERE entry_id IS NOT NULL);
        DELETE FROM universal.entry WHERE id IN (SELECT entry_id FROM test.cleanup WHERE entry_id IS NOT NULL);
        DELETE FROM universal.entry WHERE patient_id IN (SELECT patient_id FROM test.cleanup WHERE patient_id IS NOT NULL);
        DELETE FROM universal.patient WHERE id IN (SELECT patient_id FROM test.cleanup WHERE patient_id IS NOT NULL);
        DELETE FROM concept.code_mapping WHERE concept_key IN (SELECT concept_key FROM test.cleanup WHERE concept_key IS NOT NULL) OR text_pattern IN (SELECT text_pattern FROM test.cleanup WHERE text_pattern IS NOT NULL);
        DELETE FROM test.cleanup;
        DELETE FROM test.tests;*/
	END
$$;
ALTER FUNCTION test.master(p_verbose boolean) OWNER TO postgres;
SET search_path = concept, pg_catalog;
--
-- Name: code_mapping_new_id_seq; Type: SEQUENCE; Schema: concept; Owner: postgres
--
CREATE SEQUENCE code_mapping_new_id_seq
    START WITH 293
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER TABLE code_mapping_new_id_seq OWNER TO postgres;
SET default_tablespace = '';
SET default_with_oids = false;
--
-- Name: code_mapping; Type: TABLE; Schema: concept; Owner: postgres
--
CREATE TABLE code_mapping (
    id integer DEFAULT nextval('code_mapping_new_id_seq'::regclass) NOT NULL,
    attribute_id numeric(6,3),
    concept_key text,
    code_system text,
    code_pattern text,
    text_pattern text,
    source text,
    emr_system text
);
ALTER TABLE code_mapping OWNER TO postgres;
--
-- Name: entry_mapping; Type: TABLE; Schema: concept; Owner: postgres
--
CREATE TABLE entry_mapping (
    entry_id integer,
    start_attribute_id numeric(6,3),
    end_attribute_id numeric(6,3)
);
ALTER TABLE entry_mapping OWNER TO postgres;
SET search_path = test, pg_catalog;
--
-- Name: cleanup; Type: TABLE; Schema: test; Owner: postgres
--
CREATE TABLE cleanup (
    entry_id integer,
    patient_id integer,
    concept_key text,
    text_pattern text
);
ALTER TABLE cleanup OWNER TO postgres;
--
-- Name: COLUMN cleanup.entry_id; Type: COMMENT; Schema: test; Owner: postgres
--
COMMENT ON COLUMN cleanup.entry_id IS 'Id of an entry to delete';
--
-- Name: COLUMN cleanup.patient_id; Type: COMMENT; Schema: test; Owner: postgres
--
COMMENT ON COLUMN cleanup.patient_id IS 'Id of a patient to delete';
--
-- Name: tests; Type: TABLE; Schema: test; Owner: postgres
--
CREATE TABLE tests (
    selects text[],
    function text,
    parameters text[],
    expectation text,
    message text,
    schema text
);
ALTER TABLE tests OWNER TO postgres;
--
-- Name: COLUMN tests.selects; Type: COMMENT; Schema: test; Owner: postgres
--
COMMENT ON COLUMN tests.selects IS 'The field names to be selected from the functions';
--
-- Name: COLUMN tests.function; Type: COMMENT; Schema: test; Owner: postgres
--
COMMENT ON COLUMN tests.function IS 'The name of the function to be called
';
--
-- Name: COLUMN tests.parameters; Type: COMMENT; Schema: test; Owner: postgres
--
COMMENT ON COLUMN tests.parameters IS 'The parameter values to pass the function
';
--
-- Name: COLUMN tests.expectation; Type: COMMENT; Schema: test; Owner: postgres
--
COMMENT ON COLUMN tests.expectation IS 'Either ''NULL'' or ''VALUE'' ';
--
-- Name: COLUMN tests.message; Type: COMMENT; Schema: test; Owner: postgres
--
COMMENT ON COLUMN tests.message IS 'If the expectation is not found, this is the error message
';
SET search_path = universal, pg_catalog;
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
-- Name: state; Type: TABLE; Schema: universal; Owner: postgres
--
CREATE TABLE state (
    id bigint NOT NULL,
    record_type text NOT NULL,
    record_id bigint NOT NULL,
    state text DEFAULT 'active'::text,
    effective_date timestamp with time zone,
    emr_id text,
    emr_reference text
);
ALTER TABLE state OWNER TO postgres;
--
-- Name: mat_active_state; Type: MATERIALIZED VIEW; Schema: universal; Owner: postgres
--
CREATE MATERIALIZED VIEW mat_active_state AS
 WITH ranked AS (
         SELECT state.record_id,
            state.record_type,
            state.state,
            state.effective_date,
            state.emr_id,
            state.emr_reference,
            rank() OVER (PARTITION BY state.record_id, state.record_type ORDER BY state.effective_date, state.id) AS rank
           FROM state
        )
 SELECT DISTINCT r1.record_id,
    r1.record_type,
    r1.effective_date AS effective_start_date,
    COALESCE(r2.effective_date, '2100-01-01 00:00:00-08'::timestamp with time zone) AS effective_end_date,
    r1.emr_id,
    r1.emr_reference
   FROM ((ranked r1
     LEFT JOIN ranked r2 ON (((r1.record_type = r2.record_type) AND (r1.record_id = r2.record_id) AND ((r1.rank + 1) = r2.rank))))
     CROSS JOIN ( SELECT DISTINCT code_mapping.text_pattern
           FROM concept.code_mapping
          WHERE (lower(code_mapping.concept_key) = 'active state'::text)) act)
  WHERE (r1.state ~* act.text_pattern)
  WITH NO DATA;
ALTER TABLE mat_active_state OWNER TO postgres;
--
-- Name: mat_entry_attribute; Type: MATERIALIZED VIEW; Schema: universal; Owner: postgres
--
CREATE MATERIALIZED VIEW mat_entry_attribute AS
 WITH rankedea AS (
         SELECT entry_attribute.id,
            entry_attribute.entry_id,
            entry_attribute.attribute_id,
            entry_attribute.code_system,
            entry_attribute.code_value,
            entry_attribute.text_value,
            entry_attribute.date_value,
            entry_attribute.boolean_value,
            entry_attribute.numeric_value,
            entry_attribute.emr_id,
            entry_attribute.emr_reference,
            entry_attribute.emr_effective_date,
            entry_attribute.hdc_effective_date,
            rank() OVER (PARTITION BY entry_attribute.entry_id, entry_attribute.attribute_id ORDER BY entry_attribute.emr_effective_date, entry_attribute.id) AS rank
           FROM entry_attribute
        )
 SELECT r1.entry_id,
    r1.attribute_id,
    r1.code_system,
    r1.code_value,
    r1.text_value,
    r1.date_value,
    r1.boolean_value,
    r1.numeric_value,
    r1.emr_id,
    r1.emr_effective_date AS emr_effective_start_date,
    COALESCE(r2.emr_effective_date, ('2100-01-01'::date)::timestamp with time zone) AS emr_effective_end_date,
    r1.hdc_effective_date
   FROM (rankedea r1
     LEFT JOIN rankedea r2 ON (((r1.entry_id = r2.entry_id) AND (r1.attribute_id = r2.attribute_id) AND (r2.rank = (r1.rank + 1)))))
  WITH NO DATA;
ALTER TABLE mat_entry_attribute OWNER TO postgres;
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
SET search_path = concept, pg_catalog;
--
-- Name: code_mapping code_mapping_pkey; Type: CONSTRAINT; Schema: concept; Owner: postgres
--
ALTER TABLE ONLY code_mapping
    ADD CONSTRAINT code_mapping_pkey PRIMARY KEY (id);
SET search_path = universal, pg_catalog;
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
CREATE INDEX idx_entry_attribute_code_system ON entry_attribute USING btree (lower(code_system));
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
-- Name: idx_mat_entry_attribute_attribute_id; Type: INDEX; Schema: universal; Owner: postgres
--
CREATE INDEX idx_mat_entry_attribute_attribute_id ON mat_entry_attribute USING btree (attribute_id);
--
-- Name: idx_mat_entry_attribute_code_system; Type: INDEX; Schema: universal; Owner: postgres
--
CREATE INDEX idx_mat_entry_attribute_code_system ON mat_entry_attribute USING btree (code_system);
--
-- Name: idx_mat_entry_attribute_code_value; Type: INDEX; Schema: universal; Owner: postgres
--
CREATE INDEX idx_mat_entry_attribute_code_value ON mat_entry_attribute USING btree (code_value);
--
-- Name: idx_mat_entry_attribute_date_value; Type: INDEX; Schema: universal; Owner: postgres
--
CREATE INDEX idx_mat_entry_attribute_date_value ON mat_entry_attribute USING btree (date_value);
--
-- Name: idx_mat_entry_attribute_entry_id; Type: INDEX; Schema: universal; Owner: postgres
--
CREATE INDEX idx_mat_entry_attribute_entry_id ON mat_entry_attribute USING btree (entry_id);
--
-- Name: idx_mat_entry_attribute_text_value; Type: INDEX; Schema: universal; Owner: postgres
--
CREATE INDEX idx_mat_entry_attribute_text_value ON mat_entry_attribute USING btree (text_value);
--
-- Name: mat_state_effective_end_date_idx; Type: INDEX; Schema: universal; Owner: postgres
--
CREATE INDEX mat_state_effective_end_date_idx ON mat_active_state USING btree (effective_end_date);
--
-- Name: mat_state_effective_start_date_idx; Type: INDEX; Schema: universal; Owner: postgres
--
CREATE INDEX mat_state_effective_start_date_idx ON mat_active_state USING btree (effective_start_date);
--
-- Name: mat_state_record_id_idx; Type: INDEX; Schema: universal; Owner: postgres
--
CREATE INDEX mat_state_record_id_idx ON mat_active_state USING btree (record_id);
--
-- Name: mat_state_record_type_idx; Type: INDEX; Schema: universal; Owner: postgres
--
CREATE INDEX mat_state_record_type_idx ON mat_active_state USING btree (record_type);
--
-- Name: patient_practitioner_practitioner_id_idx; Type: INDEX; Schema: universal; Owner: postgres
--
CREATE INDEX patient_practitioner_practitioner_id_idx ON patient_practitioner USING btree (practitioner_id);
--
-- Name: practitioner_identifier_type_id_idx; Type: INDEX; Schema: universal; Owner: postgres
--
CREATE INDEX practitioner_identifier_type_id_idx ON practitioner USING btree (identifier_type, id);
--
-- Name: state_record_type_effective_date_idx; Type: INDEX; Schema: universal; Owner: postgres
--
CREATE INDEX state_record_type_effective_date_idx ON state USING btree (record_type, effective_date DESC);
--
-- Name: state_state_idx; Type: INDEX; Schema: universal; Owner: postgres
--
CREATE INDEX state_state_idx ON state USING btree (state);
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
