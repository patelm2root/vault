DROP SCHEMA IF EXISTS concept CASCADE;

CREATE SCHEMA concept;

CREATE TABLE concept.code_mapping
(
  concept_key text,
  code_system text,
  specific_code text,
  code_pattern text,
  freetext_include text,
  freetext_exclude text,
  source text,
  emr_system text,
  attribute_id numeric(6,3)
);

CREATE TABLE concept.entry_mapping
(
  entry_id integer,
  start_attribute_id numeric(6,3),
  end_attribute_id numeric(6,3)
);

-- Function: concept.map(text, date)

-- DROP FUNCTION concept.map(text, date);

CREATE OR REPLACE FUNCTION concept.map(
    p_concept_key text,
    p_effective_date date)
  RETURNS SETOF universal.entry_attribute AS
$BODY$

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
   SELECT *
     FROM t2
    WHERE start_rank = 1
      AND end_rank = 1
      AND start_date <= p_effective_date
      AND end_date IS NULL OR (end_date >= p_effective_date)
 ORDER BY emr_patient_id::int,
          emr_entry_id::int;

$BODY$
  LANGUAGE sql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION concept.map(text, date)
  OWNER TO postgres;
