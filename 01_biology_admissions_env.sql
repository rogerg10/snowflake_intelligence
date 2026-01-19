
-- ============================================================
-- File: 01_biology_admissions_env.sql
-- Purpose:
--   Create only the objects required by the business logic in:
--   02_biology_admissions_business_logic.sql
--
--   Required objects (referenced by functions / procedures):
--     - DATABASE  BIOLOGY_ADMISSIONS_DB
--     - SCHEMA    INTAKE_2025_26
--     - TABLE     ADMISSIONS_INTELLIGENCE.DATA.TMP_INVOICE_PDF_STAGE
--     - TABLE     BIOLOGY_ADMISSIONS_DB.INTAKE_2025_26.FINANCIAL_RECORDS
--     - TABLE     BIOLOGY_ADMISSIONS_DB.INTAKE_2025_26.CONFIRMED_APPLICANTS
--     - NOTEBOOK  ADMISSIONS_INTELLIGENCE.DATA."Invoice Generator" (external)
--     - EXTERNAL ACCESS INTEGRATIONS:
--           invoice_api_integration
--           plane_api_integration
-- ============================================================

------------------------------------------------------------
-- 0. Context
------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

-- Assumes BIOLOGY_ADMISSIONS_DB and schema INTAKE_2025_26 already exist.
USE DATABASE BIOLOGY_ADMISSIONS_DB;
USE SCHEMA INTAKE_2025_26;

------------------------------------------------------------
-- 1. Temp table for invoice PDFs
--    Used by PROCEDURE generate_and_store_invoice
------------------------------------------------------------
CREATE OR REPLACE DATABASE admissions_intelligence;
CREATE OR REPLACE SCHEMA admissions_intelligence.data;

CREATE OR REPLACE TABLE ADMISSIONS_INTELLIGENCE.DATA.TMP_INVOICE_PDF_STAGE (
    invoice_number STRING,
    pdf_base64 STRING,
    created_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP
);

------------------------------------------------------------
-- 2. Financial records table
--    Used by PROCEDURE generate_and_store_invoice
--      - UPDATE ADMISSIONS_INTELLIGENCE.DATA.FINANCIAL_RECORDS
--          SET invoice_pdf_path, pdf_generated_timestamp
--          WHERE invoice_number = ?
------------------------------------------------------------
CREATE OR REPLACE TABLE BIOLOGY_ADMISSIONS_DB.INTAKE_2025_26.FINANCIAL_RECORDS (
    financial_record_id        VARCHAR,
    student_id                 NUMBER,
    invoice_number             VARCHAR,
    item_name                  VARCHAR,
    currency                   VARCHAR,
    amount                     NUMBER(10,2),
    quantity                   NUMBER,
    unit_cost                  NUMBER(10,2),
    record_type                VARCHAR,          -- e.g. 'INVOICE'
    payment_status             VARCHAR,          -- e.g. 'PENDING'
    payment_method             VARCHAR,
    terms                      VARCHAR,
    created_timestamp          TIMESTAMP_NTZ,
    due_date                   DATE,
    payment_date               DATE,
    pdf_generated_timestamp    TIMESTAMP_NTZ,
    invoice_pdf_path           VARCHAR,
    from_name                  VARCHAR,
    to_name                    VARCHAR
);

-- Minimal demo row used by example call in file 2
INSERT INTO BIOLOGY_ADMISSIONS_DB.INTAKE_2025_26.FINANCIAL_RECORDS (
    financial_record_id,
    student_id,
    invoice_number,
    item_name,
    currency,
    amount,
    quantity,
    unit_cost,
    record_type,
    payment_status,
    payment_method,
    terms,
    created_timestamp,
    due_date,
    from_name,
    to_name
) VALUES (
    'FR-INV-2001',
    12345,
    'INV-2001',
    'MSc Biology Tuition',
    'AUD',
    10000,
    1,
    10000,
    'INVOICE',
    'PENDING',
    NULL,
    'Net 30',
    CURRENT_TIMESTAMP,
    '2025-11-10',
    'University Admissions Office',
    'Alice Lee'
);

------------------------------------------------------------
-- 3. Confirmed applicants table
--    Used by:
--      - PROCEDURE generate_and_store_invoice
--          UPDATE ... SET INVOICING_STARTED = TRUE WHERE STUDENT_ID = ?
--      - PROCEDURE create_issue_and_update_onboarding
--          UPDATE ... SET ONBOARDING_STARTED = TRUE WHERE STUDENT_ID = ?
------------------------------------------------------------
CREATE OR REPLACE TABLE BIOLOGY_ADMISSIONS_DB.INTAKE_2025_26.CONFIRMED_APPLICANTS (
    student_id          NUMBER,
    applicant_id        VARCHAR,
    student_number      VARCHAR,
    first_name          VARCHAR,
    last_name           VARCHAR,
    program_code        VARCHAR,
    program_name        VARCHAR,
    campus              VARCHAR,
    study_mode          VARCHAR,
    student_type        VARCHAR,
    enrollment_status   VARCHAR,
    confirmation_date   DATE,
    expected_start_date DATE,
    created_timestamp   TIMESTAMP_NTZ,
    created_by          VARCHAR,
    tuition_amount      NUMBER(10,2),
    onboarding_started  BOOLEAN DEFAULT FALSE,
    invoicing_started   BOOLEAN DEFAULT FALSE
);

-- Minimal demo row used by example calls in file 2
INSERT INTO BIOLOGY_ADMISSIONS_DB.INTAKE_2025_26.CONFIRMED_APPLICANTS (
    student_id,
    applicant_id,
    student_number,
    first_name,
    last_name,
    program_code,
    program_name,
    campus,
    study_mode,
    student_type,
    enrollment_status,
    confirmation_date,
    expected_start_date,
    created_timestamp,
    created_by,
    tuition_amount,
    onboarding_started,
    invoicing_started
) VALUES (
    12345,
    'A2026_001',
    'B232001',
    'Alice',
    'Lee',
    'BIO101',
    'MSc Biology',
    'Parkville',
    'FULL_TIME',
    'DOMESTIC',
    'CONFIRMED',
    '2025-08-01',
    '2025-09-01',
    CURRENT_TIMESTAMP,
    'system_proc',
    10000,
    FALSE,
    FALSE
);

------------------------------------------------------------
-- 4. Notes / prerequisites (not created here)
------------------------------------------------------------
-- The following must exist before running 02_biology_admissions_business_logic.sql:
--   - External access integration: invoice_api_integration
--   - External access integration: plane_api_integration
--   - Notebook: ADMISSIONS_INTELLIGENCE.DATA."Invoice Generator"

