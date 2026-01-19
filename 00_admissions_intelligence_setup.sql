-- =====================================================================
-- All data, names, and values in this script are dummy and for demo use.
-- This script is intended for prototype and learning scenarios and is not
-- designed for production use.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Create and assign a consumer role for Admissions Intelligence
-- ---------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE ROLE ADMISSIONS_INTELLIGENCE_RL;

-- Grant Cortex / Intelligence capabilities to this role
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER
  TO ROLE ADMISSIONS_INTELLIGENCE_RL;

-- Optionally grant the role to the current user for testing
SET my_user = CURRENT_USER();
GRANT ROLE ADMISSIONS_INTELLIGENCE_RL TO USER IDENTIFIER($my_user);

-- ---------------------------------------------------------------------
-- 1. Core database, schema, and warehouse for Admissions Intelligence
-- ---------------------------------------------------------------------

-- Primary demo database and schema for admissions data
CREATE OR REPLACE DATABASE ADMISSIONS_INTELLIGENCE;
CREATE OR REPLACE SCHEMA ADMISSIONS_INTELLIGENCE.DATA;

GRANT USAGE ON DATABASE ADMISSIONS_INTELLIGENCE
  TO ROLE ADMISSIONS_INTELLIGENCE_RL;

GRANT USAGE ON SCHEMA ADMISSIONS_INTELLIGENCE.DATA
  TO ROLE ADMISSIONS_INTELLIGENCE_RL;

-- Database where Intelligence Agents are stored
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS;

GRANT USAGE ON DATABASE SNOWFLAKE_INTELLIGENCE
  TO ROLE ADMISSIONS_INTELLIGENCE_RL;

GRANT USAGE ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS
  TO ROLE ADMISSIONS_INTELLIGENCE_RL;

-- Allow the role to create agents in the AGENTS schema
GRANT CREATE AGENT ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS
  TO ROLE ADMISSIONS_INTELLIGENCE_RL;

-- Warehouse dedicated to admissions workloads
CREATE OR REPLACE WAREHOUSE ADMISSIONS_INTELLIGENCE_WH
WITH
    WAREHOUSE_SIZE      = 'SMALL'
  , AUTO_SUSPEND        = 60      
  , AUTO_RESUME         = TRUE
  , INITIALLY_SUSPENDED = FALSE
  COMMENT = 'Admissions intelligence demo warehouse with 1-minute auto-suspend';

GRANT USAGE, OPERATE
  ON WAREHOUSE ADMISSIONS_INTELLIGENCE_WH
  TO ROLE ADMISSIONS_INTELLIGENCE_RL;

-- ---------------------------------------------------------------------
-- 2. Demo admissions data model (interviews and metrics)
-- ---------------------------------------------------------------------
USE ROLE ADMISSIONS_INTELLIGENCE_RL;
USE DATABASE ADMISSIONS_INTELLIGENCE;
USE SCHEMA DATA;

-- Raw/intermediate interview transcripts
CREATE OR REPLACE TABLE ADMISSIONS_INTERVIEWS (
    INTERVIEW_ID      VARCHAR,
    TRANSCRIPT_TEXT   TEXT,
    APPLICANT_NAME    VARCHAR,
    INTERVIEW_STAGE   VARCHAR,
    INTERVIEWER       VARCHAR,
    INTERVIEW_DATE    TIMESTAMP,
    PROGRAM_VALUE     FLOAT,
    PROGRAM_TYPE      VARCHAR
);

GRANT SELECT ON TABLE ADMISSIONS_INTERVIEWS
  TO ROLE ADMISSIONS_INTELLIGENCE_RL;

-- Aggregated or structured admissions metrics
CREATE OR REPLACE TABLE ADMISSIONS_METRICS (
    APPLICATION_ID      VARCHAR,
    APPLICANT_NAME      VARCHAR,
    PROGRAM_VALUE       FLOAT,
    DECISION_DATE       DATE,
    APPLICATION_STAGE   VARCHAR,
    ACCEPTANCE_STATUS   BOOLEAN,
    INTERVIEWER         VARCHAR,
    PROGRAM_TYPE        VARCHAR
);

GRANT SELECT ON TABLE ADMISSIONS_METRICS
  TO ROLE ADMISSIONS_INTELLIGENCE_RL;

-- Optionally insert a couple of tiny dummy rows for quick smoke testing.

INSERT INTO ADMISSIONS_INTERVIEWS (
    INTERVIEW_ID,
    TRANSCRIPT_TEXT,
    APPLICANT_NAME,
    INTERVIEW_STAGE,
    INTERVIEWER,
    INTERVIEW_DATE,
    PROGRAM_VALUE,
    PROGRAM_TYPE
)
VALUES
    (
      'INT-001',
      'Dummy transcript text for admissions interview example only.',
      'Alex Doe',
      'FIRST_ROUND',
      'Dr. Smith',
      '2025-08-01 10:00:00',
      1.0,
      'MSC_BIOLOGY'
    );

INSERT INTO ADMISSIONS_METRICS (
    APPLICATION_ID,
    APPLICANT_NAME,
    PROGRAM_VALUE,
    DECISION_DATE,
    APPLICATION_STAGE,
    ACCEPTANCE_STATUS,
    INTERVIEWER,
    PROGRAM_TYPE
)
VALUES
    (
      'APP-001',
      'Alex Doe',
      1.0,
      '2025-08-15',
      'OFFER_MADE',
      TRUE,
      'Dr. Smith',
      'MSC_BIOLOGY'
    );
