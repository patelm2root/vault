\connect vault
DROP SCHEMA IF EXISTS concept CASCADE;  
DROP FUNCTION IF EXISTS concept.map(p_concept_key,p_effective_date) CASCADE; CREATE OR REPLACE FUNCTION concept.map(p_concept_key text, p_effective_date date)
 RETURNS SETOF bigint
 LANGUAGE sql
AS $function$

WITH t1
AS
(
   SELECT p.id as patient_id,
          p.emr_id as emr_patient_id, 
          e.emr_table, 
          e.id as entry_id,
          e.emr_id as emr_entry_id, 
          es.id as entry_state_id,
          es.state,
          es.effective_date, 
          ea.code_system, 
          ea.code_value, 
          ea.text_value, 
          ea.emr_effective_date, 
          ea_start.id as start_id,
          ea_start.date_value as start_date, 
          ea_start.emr_effective_date as start_effective_date, 
          ea_end.id as end_id,
          ea_end.date_value as end_date, 
          ea_end.emr_effective_date as end_effective_date,
          RANK() OVER(PARTITION BY p.id, e.id ORDER BY es.effective_date DESC, es.id DESC) as entry_state_rank
     FROM concept.code_mapping as cm
     JOIN universal.entry_attribute as ea
       ON (cm.attribute_id IS NULL OR cm.attribute_id = ea.attribute_id)
      AND (cm.code_system IS NULL OR cm.code_system = ea.code_system)
      AND (cm.specific_code IS NULL or cm.specific_code = ea.code_value)
      AND (cm.code_pattern IS NULL OR ea.code_value like cm.code_pattern)
      AND (cm.freetext_include IS NULL OR (ea.text_value LIKE cm.freetext_include))
      AND (cm.freetext_exclude IS NULL OR (ea.text_value NOT LIKE cm.freetext_exclude))
     JOIN universal.state as es
       ON es.record_type = 'entry'
      AND es.record_id = ea.entry_id

     JOIN concept.entry_mapping as em
       ON em.entry_id = ea.attribute_id::int
LEFT JOIN universal.entry_attribute as ea_start
       ON ea_start.entry_id = ea.entry_id
      AND ea_start.attribute_id = em.start_attribute_id  
      AND ea_start.emr_effective_date <= p_effective_date
          
LEFT JOIN universal.entry_attribute as ea_end
       ON ea_end.entry_id = ea.entry_id
      AND ea_end.attribute_id = em.end_attribute_id
      AND ea_end.emr_effective_date <= p_effective_date
      
     JOIN universal.entry as e
       ON e.id = ea.entry_id
     JOIN universal.patient as p
       ON p.id = e.patient_id
       
    WHERE cm.concept_key = p_concept_key
      AND es.effective_date < p_effective_date
),
t2 AS
(
   SELECT *,
          RANK() OVER (PARTITION BY entry_id ORDER BY start_effective_date DESC, start_id DESC) as start_rank,
          RANK() OVER (PARTITION BY entry_id ORDER BY end_effective_date DESC, end_id DESC) as end_rank
     FROM t1
    WHERE entry_state_rank = 1
)
   SELECT distinct patient_id
     FROM t2
    WHERE start_rank = 1
      AND end_rank = 1
      AND start_date <= p_effective_date
      AND end_date IS NULL OR (end_date >= p_effective_date);

$function$
;
DROP FUNCTION IF EXISTS concept.practitioner(p_practitioner_msp,p_effective_date,patient_id) CASCADE; CREATE OR REPLACE FUNCTION concept.practitioner(p_practitioner_msp text, p_effective_date date)
 RETURNS TABLE(patient_id bigint)
 LANGUAGE plpgsql
AS $function$
BEGIN
    /* p_effective_date is not being used yet */
    RETURN QUERY
        SELECT pp.patient_id
        FROM universal.practitioner as p
        JOIN universal.patient_practitioner as pp
            ON p.id = pp.practitioner_id
        WHERE 
            p.identifier_type = 'MSP'
            AND p.identifier = p_practitioner_MSP;
END  
$function$
;
DROP FUNCTION IF EXISTS concept.observation(p_concept_key,p_min_date,p_max_date,p_bottom_value,p_top_value,patient_id) CASCADE; CREATE OR REPLACE FUNCTION concept.observation(p_concept_key text, p_min_date date, p_max_date date, p_bottom_value double precision, p_top_value double precision)
 RETURNS TABLE(patient_id bigint)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH patientsWithObservation AS (
        SELECT p.patient_id, ea.text_value, ea.emr_effective_date
        -- Find all patients with an observation of p_concept_key type
        FROM concept.map_simple(p_concept_key, current_date) as p
        -- for observation values
        JOIN universal.entry_attribute as ea
            ON ea.entry_id = p.entry_id
            AND ea.attribute_id = 009.003)
    SELECT p.patient_id
    FROM patientsWithObservation p
    WHERE 
        CAST(p.text_value AS FLOAT) BETWEEN p_bottom_value AND p_top_value
        AND emr_effective_date BETWEEN p_min_date AND p_max_date;
END  
$function$
;
DROP FUNCTION IF EXISTS concept.clinic(p_clinic_reference,p_effective_date,patient_id) CASCADE; CREATE OR REPLACE FUNCTION concept.clinic(p_clinic_reference text, p_effective_date date)
 RETURNS TABLE(patient_id bigint)
 LANGUAGE plpgsql
AS $function$
BEGIN
    /* p_effective_date is not being used yet (comes from state table)*/
    RETURN QUERY
        SELECT p.id as patient_id
        FROM universal.patient as p
        JOIN universal.clinic as c
            ON p.clinic_id = c.id
        WHERE 
            c.hdc_reference = p_clinic_reference;
END  
$function$
;
DROP FUNCTION IF EXISTS concept.map_simple_v1(p_concept_key,p_effective_date,patient_id,entry_id) CASCADE; CREATE OR REPLACE FUNCTION concept.map_simple_v1(p_concept_key text, p_effective_date date)
 RETURNS TABLE(patient_id bigint, entry_id bigint)
 LANGUAGE plpgsql
AS $function$
BEGIN
    
    RETURN QUERY
    WITH t1
    AS
    (
       SELECT p.id as p_id,
              e.id as entry_id,
              RANK() OVER(PARTITION BY p.id, e.id ORDER BY es.effective_date DESC, es.id DESC) as entry_state_rank
         FROM concept.code_mapping as cm
         JOIN universal.entry_attribute as ea
           ON cm.attribute_id = ea.attribute_id
          AND (cm.code_system IS NULL OR cm.code_system = ea.code_system)
          AND (cm.specific_code IS NULL or cm.specific_code = ea.code_value)
          AND (cm.code_pattern IS NULL OR ea.code_value like cm.code_pattern)
          AND (cm.freetext_include IS NULL OR (ea.text_value LIKE cm.freetext_include))
          AND (cm.freetext_exclude IS NULL OR (ea.text_value NOT LIKE cm.freetext_exclude))
         JOIN universal.state as es
           ON es.record_type = 'entry'
          AND es.record_id = ea.entry_id
         JOIN universal.entry as e
           ON e.id = ea.entry_id
         JOIN universal.patient as p
           ON p.id = e.patient_id
           
        WHERE cm.concept_key = p_concept_key
          AND es.effective_date < p_effective_date
    )
       SELECT t1.p_id, t1.entry_id
         FROM t1
        WHERE entry_state_rank = 1;
END
$function$
;
DROP FUNCTION IF EXISTS concept.patient_age(p_effective_date,p_active,p_min_age,p_max_age,p_gender,patient_id) CASCADE; CREATE OR REPLACE FUNCTION concept.patient_age(p_effective_date date, p_active boolean DEFAULT true, p_min_age interval DEFAULT NULL::interval, p_max_age interval DEFAULT NULL::interval, p_gender text DEFAULT NULL::text)
 RETURNS TABLE(patient_id bigint)
 LANGUAGE sql
AS $function$
	WITH patientAges as (
		SELECT p.patient_id , ea.date_value AS date_birth, ea.emr_effective_date
		FROM concept.map_simple('age', p_effective_date) AS p
		JOIN universal.entry_attribute AS ea
			ON ea.entry_id = p.entry_id
			AND ea.attribute_id = 5.001
	)
	
    SELECT DISTINCT 
		p.id as patient_id 
    FROM universal.patient as p
    WHERE 
		-- Check patient gender
		(p_gender IS NULL OR p.id IN (select patient_id from concept.map_simple(p_gender, p_effective_date)))

		-- Check patient minimum age
		AND (
			p.id IN (
				SELECT patient_id
				FROM patientAges AS pa
				WHERE 
					(p_min_age IS NULL OR age(p_effective_date, date_birth) >= p_min_age)
					AND 
					(p_max_age IS NULL OR age(p_effective_date, date_birth) <= p_max_age)
			)	
		);

		
      /*
     WHERE (min_age IS NULL OR age(patient.effective_date, p_info.birth_date) >= min_age)
       AND (max_age IS NULL OR age(patient.effective_date, p_info.birth_date) <= max_age)
       AND (patient.gender IS NULL OR p_info.gender = patient.gender)
AND (
	(active IS NULL)
	OR
	(active = TRUE 
		AND universal.entry.occurrence_date >= (patient.effective_date - '3 year'::interval) -- temporary active check of any entry in the last 3 years
		)
	OR
	(active = FALSE 
		AND NOT EXISTS (SELECT 1 
                   FROM universal.entry
                  WHERE patient_id = p.id
                  AND universal.entry.occurrence_date >= (patient.effective_date - '3 year'::interval) -- temporary active check of any entry in the last 3 years)
                  )
	)*/

$function$
;
DROP FUNCTION IF EXISTS concept.prescription_active(p_concept_key,p_effective_date,patient_id) CASCADE; CREATE OR REPLACE FUNCTION concept.prescription_active(p_concept_key text, p_effective_date date)
 RETURNS TABLE(patient_id bigint)
 LANGUAGE plpgsql
AS $function$
BEGIN
    /*
        Description:
            Returns the list of patients that were actively taking a medication on a given date
    */    
    RETURN QUERY
        WITH starts AS (
            -- Find the most recent start date for this prescription
            SELECT
                ea.entry_id,
                ea.date_value as start_date,
                RANK() OVER (PARTITION BY ea.entry_id ORDER BY ea.emr_effective_date DESC, ea.id DESC) as start_rank
            FROM universal.entry_attribute as ea
            WHERE attribute_id = 12.008
                AND ea.emr_effective_date <= p_effective_date
        )
        ,stops AS (
            -- Find the most recent stop date for this prescription
            SELECT
                ea.entry_id,
                ea.date_value as stop_date,
                RANK() OVER (PARTITION BY ea.entry_id ORDER BY ea.emr_effective_date DESC, ea.id DESC) as stop_rank
            FROM universal.entry_attribute as ea
            WHERE attribute_id = 12.009
                AND ea.emr_effective_date <= p_effective_date 
        )
        ,prescriptions AS (
            -- Find the most recent status for this prescription as a whole for the given p_effective_date
            SELECT 
                e.patient_id, 
                es.state,
                RANK() OVER(PARTITION BY e.patient_id, e.id ORDER BY es.effective_date DESC, es.id DESC) as entry_state_rank
            FROM universal.entry as e
            JOIN universal.entry_attribute as ea
                ON e.id = ea.entry_id
                AND ea.attribute_id = 12.001
            JOIN starts
                ON e.id = starts.entry_id
                AND starts.start_rank = 1
            JOIN stops
                ON e.id = stops.entry_id
                AND stops.stop_rank = 1
            JOIN universal.state as es
                ON es.record_type = 'entry'
                AND es.record_id = e.id
            WHERE 
                p_effective_date BETWEEN starts.start_date AND stops.stop_date
                AND es.effective_date < p_effective_date
                AND e.patient_id IN (SELECT ms.patient_id FROM concept.map_simple(p_concept_key, p_effective_date) as ms))
        -- 
        SELECT 
			p.patient_id
        FROM prescriptions as p
        WHERE p.entry_state_rank = 1;
END  
$function$
;
DROP FUNCTION IF EXISTS concept.map_simple(p_concept_key,p_effective_date,patient_id,entry_id) CASCADE; CREATE OR REPLACE FUNCTION concept.map_simple(p_concept_key text, p_effective_date date)
 RETURNS TABLE(patient_id bigint, entry_id bigint)
 LANGUAGE plpgsql
AS $function$
BEGIN
/*
    Description: Finds all patients that have a 'concept'
*/
    RETURN QUERY
    WITH MostRecentValues as (
        -- Need to rank the attribute values so as to find the one effective on p_effective_date
        SELECT
            *,
            RANK() OVER(PARTITION BY ea.entry_id, ea.attribute_id ORDER BY ea.emr_effective_date DESC, ea.id DESC) as entry_attribute_rank
        FROM universal.entry_attribute as ea
        WHERE
            ea.attribute_id IN (SELECT attribute_id FROM concept.code_mapping WHERE concept_key = p_concept_key) 
            AND ea.emr_effective_date <= p_effective_date    
    ),
    MatchingPatients AS (
       -- Match attributes to concepts to find patients with this concept
       SELECT e.patient_id,
              e.id as entry_id
         FROM concept.code_mapping as cm
         JOIN MostRecentValues as ea
           ON cm.attribute_id = ea.attribute_id
          AND (
			-- Regex match on code_value
			((cm.code_system IS NULL OR cm.code_system = ea.code_system)
            AND 
            (ea.code_value ~* cm.code_pattern))

			OR

			-- Allow unpatterned attributes like 'age'
			(cm.code_pattern IS NULL AND cm.text_pattern IS NULL AND cm.code_system IS NULL)

			OR 

			-- Regex match on text_value
			((cm.code_system IS NULL OR cm.code_system = ea.code_system)
            AND 
            (ea.text_value ~* cm.text_pattern)))
         
          -- Join back to get the patient id
         JOIN universal.entry as e
           ON e.id = ea.entry_id
           
        WHERE cm.concept_key = p_concept_key
          -- Only look at the effective attribute value for the given p_effective_date
          AND ea.entry_attribute_rank = 1
    ),
    ActiveState as (
       -- Return the patient id that matches the concept
       SELECT mp.patient_id, mp.entry_id, es.state,
            RANK() OVER(PARTITION BY mp.entry_id ORDER BY es.effective_date DESC, es.id DESC) as entry_state_rank
         FROM MatchingPatients as mp
         JOIN universal.state as es
            ON mp.entry_id = es.record_id
           AND es.record_type = 'entry'
           AND es.effective_date <= p_effective_date
          )
    SELECT DISTINCT
        act.patient_id, act.entry_id
    FROM ActiveState as act
    -- Check that the state of the entry is 'active'
     JOIN concept.code_mapping as cm_state
       ON COALESCE(act.state, 'active') ~* cm_state.text_pattern 
       AND cm_state.concept_key = 'active state'
    WHERE act.entry_state_rank = 1;
END
$function$
;
DROP FUNCTION IF EXISTS concept.patient(p_effective_date,p_active,p_gender,patient_id) CASCADE; CREATE OR REPLACE FUNCTION concept.patient(p_effective_date date, p_active boolean DEFAULT true, p_gender text DEFAULT NULL::text)
 RETURNS TABLE(patient_id bigint)
 LANGUAGE sql
AS $function$
	
    SELECT DISTINCT 
		p.id as patient_id 
    FROM universal.patient as p
    WHERE 
		-- Check patient gender
		(p_gender IS NULL OR p.id IN (select patient_id from concept.map_simple(p_gender, p_effective_date)));

		
      /*
     WHERE (min_age IS NULL OR age(patient.effective_date, p_info.birth_date) >= min_age)
       AND (max_age IS NULL OR age(patient.effective_date, p_info.birth_date) <= max_age)
       AND (patient.gender IS NULL OR p_info.gender = patient.gender)
AND (
	(active IS NULL)
	OR
	(active = TRUE 
		AND universal.entry.occurrence_date >= (patient.effective_date - '3 year'::interval) -- temporary active check of any entry in the last 3 years
		)
	OR
	(active = FALSE 
		AND NOT EXISTS (SELECT 1 
                   FROM universal.entry
                  WHERE patient_id = p.id
                  AND universal.entry.occurrence_date >= (patient.effective_date - '3 year'::interval) -- temporary active check of any entry in the last 3 years)
                  )
	)*/

$function$
;
DROP FUNCTION IF EXISTS concept.prescription_minimum_meds(p_effective_date,p_min_med,patient_id) CASCADE; CREATE OR REPLACE FUNCTION concept.prescription_minimum_meds(p_effective_date date, p_min_med integer)
 RETURNS TABLE(patient_id bigint)
 LANGUAGE plpgsql
AS $function$
BEGIN
	/* 
		Description: Returns a list of patients that have at least the 
				minumum number of active prescriptions specified.
	*/
    RETURN QUERY
        WITH starts AS (
            -- Find the most recent start date for this prescription
            SELECT
                ea.entry_id,
                ea.date_value as start_date,
                RANK() OVER (PARTITION BY ea.entry_id ORDER BY ea.emr_effective_date DESC, ea.id DESC) as start_rank
            FROM universal.entry_attribute as ea
            WHERE attribute_id = 12.008
                AND ea.emr_effective_date <= p_effective_date
        )
        ,stops AS (
            -- Find the most recent stop date for this prescription
            SELECT
                ea.entry_id,
                ea.date_value as stop_date,
                RANK() OVER (PARTITION BY ea.entry_id ORDER BY ea.emr_effective_date DESC, ea.id DESC) as stop_rank
            FROM universal.entry_attribute as ea
            WHERE attribute_id = 12.009
                AND ea.emr_effective_date <= p_effective_date 
        )
        ,prescriptions as (
            -- Find the most recent status for this prescription as a whole
            SELECT 
                e.patient_id, 
                ea.code_value as prescription_id, 
                RANK() OVER(PARTITION BY e.patient_id, e.id ORDER BY es.effective_date DESC, es.id DESC) as entry_state_rank
            FROM universal.entry as e
            JOIN universal.entry_attribute as ea
                ON e.id = ea.entry_id
                AND ea.attribute_id = 12.001
            JOIN starts
                ON e.id = starts.entry_id
                AND starts.start_rank = 1
            JOIN stops
                ON e.id = stops.entry_id
                AND stops.stop_rank = 1
            JOIN universal.state as es
                ON es.record_type = 'entry'
                AND es.record_id = e.id
            WHERE 
                p_effective_date BETWEEN starts.start_date AND stops.stop_date
                AND es.effective_date < p_effective_date
        )
        SELECT
            p.patient_id
        FROM prescriptions as p
        WHERE p.entry_state_rank = 1
        GROUP BY 
            p.patient_id
        HAVING count(distinct p.prescription_id) >= p_min_med;    
END   
$function$
;
