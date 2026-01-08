-- Not suitable for PROD environments. 
-- Use role and correct context
-- Consider using a more pertinent role e.g. ENGINEER
USE ROLE ACCOUNTADMIN;
USE DATABASE BIOLOGY_ADMISSIONS_DB;
USE SCHEMA INTAKE_2025_26;

------------------------------------------------------------
-- 2. Secrets and external access for Invoice API
------------------------------------------------------------
CREATE OR REPLACE SECRET invoice_api_secret
    TYPE = GENERIC_STRING
    SECRET_STRING = 'INVOICE_API_KEY_PLACEHOLDER';

ALTER EXTERNAL ACCESS INTEGRATION invoice_api_integration
SET ALLOWED_AUTHENTICATION_SECRETS = (BIOLOGY_ADMISSIONS_DB.INTAKE_2025_26.INVOICE_API_SECRET);

------------------------------------------------------------
-- 3. Secure invoice generation function (Python)
------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_invoice_pdf(
    from_name STRING,
    to_name STRING,
    invoice_number STRING,
    item_name STRING,
    invoice_date STRING,
    due_date STRING,
    currency STRING,
    ship_to STRING,
    quantity FLOAT,
    tax FLOAT,
    shipping FLOAT,
    amount_paid FLOAT,
    notes STRING,
    terms STRING,
    payment_terms STRING
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = 3.12
EXTERNAL_ACCESS_INTEGRATIONS = (invoice_api_integration)
PACKAGES = ('requests')
SECRETS = ('cred' = invoice_api_secret)
HANDLER = 'create_invoice'
AS
$$
import requests
import base64
import _snowflake

def create_invoice(from_name, to_name, invoice_number, item_name, invoice_date, due_date,
                   currency, ship_to, quantity, tax, shipping, amount_paid, notes, terms, payment_terms):

    api_key = _snowflake.get_generic_secret_string('cred')

    url = "https://invoice-generator.com"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}

    data = {
        "from": from_name,
        "to": to_name,
        "number": invoice_number,
        "date": invoice_date,
        "due_date": due_date,
        "currency": currency,
        "ship_to": ship_to,
        "items": [{
            "name": item_name,
            "quantity": quantity,
            "unit_cost": amount_paid,
            "description": notes
        }],
        "tax": tax,
        "shipping": shipping,
        "amount_paid": amount_paid,
        "notes": notes,
        "terms": terms,
        "payment_terms": payment_terms
    }

    try:
        response = requests.post(url, json=data, headers=headers, timeout=20)
        response.raise_for_status()
        pdf_base64 = base64.b64encode(response.content).decode("utf-8")
        return pdf_base64
    except Exception as e:
        return f"Error: {str(e)}"
$$;

------------------------------------------------------------
-- 4. Procedure to generate invoice and update onboarding/finance
------------------------------------------------------------
CREATE OR REPLACE PROCEDURE generate_and_store_invoice(
    from_name STRING,
    to_name STRING,
    invoice_number STRING,
    item_name STRING,
    invoice_date STRING,
    due_date STRING,
    currency STRING,
    ship_to STRING,
    quantity FLOAT,
    tax FLOAT,
    shipping FLOAT,
    amount_paid FLOAT,
    notes STRING,
    terms STRING,
    payment_terms STRING,
    student_id STRING
)
RETURNS STRING
LANGUAGE JAVASCRIPT
AS
$$
try {
    var from_name        = arguments[0];
    var to_name          = arguments[1];
    var invoice_number   = arguments[2];
    var item_name        = arguments[3];
    var invoice_date     = arguments[4];
    var due_date         = arguments[5];
    var currency         = arguments[6];
    var ship_to          = arguments[7];
    var quantity         = arguments[8];
    var tax              = arguments[9];
    var shipping         = arguments[10];
    var amount_paid      = arguments[11];
    var notes            = arguments[12];
    var terms            = arguments[13];
    var payment_terms    = arguments[14];
    var student_id       = arguments[15];

    // 1. Generate base64 PDF via SQL function
    var gen_sql = `
        SELECT create_invoice_pdf(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) AS pdf_base64
    `;
    var stmt_gen = snowflake.createStatement({
        sqlText: gen_sql,
        binds: [
            from_name, to_name, invoice_number, item_name, invoice_date, due_date,
            currency, ship_to, quantity, tax, shipping, amount_paid, notes, terms, payment_terms
        ]
    });
    var rs = stmt_gen.execute();
    rs.next();
    var pdf_base64 = rs.getColumnValue('PDF_BASE64');

    // 2. Store the PDF content in temp table
    var insert_sql = `
        INSERT INTO ADMISSIONS_INTELLIGENCE.DATA.TMP_INVOICE_PDF_STAGE (invoice_number, pdf_base64)
        VALUES (?, ?)
    `;
    var stmt_insert = snowflake.createStatement({
        sqlText: insert_sql,
        binds: [invoice_number, pdf_base64]
    });
    stmt_insert.execute();

    // 3. Set invoice PDF path and timestamp on FINANCIAL_RECORDS
    var invoice_pdf_path = '@ADMISSIONS_INTELLIGENCE.DATA.INVOICE_PDF_STAGE/' || invoice_number || '.pdf';
    var pdf_generated_timestamp = new Date().toISOString();

    var update_financial_sql = `
        UPDATE ADMISSIONS_INTELLIGENCE.DATA.FINANCIAL_RECORDS
        SET invoice_pdf_path = ?, pdf_generated_timestamp = ?
        WHERE invoice_number = ?
    `;
    var stmt2 = snowflake.createStatement({
        sqlText: update_financial_sql,
        binds: [invoice_pdf_path, pdf_generated_timestamp, invoice_number]
    });
    stmt2.execute();

    // 4. Flag invoicing started on CONFIRMED_APPLICANTS
    var update_onboarding_sql = `
        UPDATE BIOLOGY_ADMISSIONS_DB.INTAKE_2025_26.CONFIRMED_APPLICANTS
        SET INVOICING_STARTED = TRUE
        WHERE STUDENT_ID = ?
    `;
    var stmt3 = snowflake.createStatement({
        sqlText: update_onboarding_sql,
        binds: [student_id]
    });
    stmt3.execute();

    // 5. Execute notebook that uploads PDF from temp table to stage
    var notebook_sql = 'EXECUTE NOTEBOOK ADMISSIONS_INTELLIGENCE.DATA."Invoice Generator"();';
    var stmt4 = snowflake.createStatement({ sqlText: notebook_sql });
    stmt4.execute();

    return 'Invoice generated, temp table updated, financial record path set, onboarding status set, and notebook executed';
} catch (err) {
    return 'Error: ' + err;
}
$$;

------------------------------------------------------------
-- 5. Example call (single test record)
------------------------------------------------------------
CALL generate_and_store_invoice(
    'University Admissions Office',
    'Alice Lee',
    'INV-2001',
    'MSc Biology Tuition',
    '2025-11-01',
    '2025-11-10',
    'AUD',
    '',
    1,
    0,
    0,
    10000,
    'Tuition for MSc Biology 2025-26',
    'Net 30',
    'Net 30',
    '12345'
);

------------------------------------------------------------
-- 6. Plane integration: function to create work item
------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_plane_work_item(
    item_name STRING,
    description_html STRING,
    priority STRING,
    start_date DATE,
    target_date DATE
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = 3.12
HANDLER = 'create_issue'
EXTERNAL_ACCESS_INTEGRATIONS = (plane_api_integration)
PACKAGES = ('requests')
AS
$$
import requests

def create_issue(item_name, description_html, priority, start_date, target_date):
    workspace_slug = 'WORKSPACE_SLUG_PLACEHOLDER'
    project_id = 'PROJECT_ID_PLACEHOLDER'
    api_key = "PLANE_API_KEY_PLACEHOLDER"

    url = f"https://api.plane.so/api/v1/workspaces/{workspace_slug}/projects/{project_id}/issues/"
    payload = {
        "name": item_name,
        "description_html": description_html,
        "priority": priority,
        "start_date": str(start_date),
        "target_date": str(target_date)
    }
    headers = {
        "x-api-key": api_key,
        "Content-Type": "application/json"
    }
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=20)
        response.raise_for_status()
        return response.text
    except requests.exceptions.HTTPError as e:
        error_msg = f"HTTPError: {e}; Response Body: {response.content.decode()}"
        return error_msg
    except Exception as exc:
        return f"Exception: {str(exc)}"
$$;

------------------------------------------------------------
-- 7. Procedure to create Plane issue and update onboarding
------------------------------------------------------------
CREATE OR REPLACE PROCEDURE create_issue_and_update_onboarding(
    item_name STRING,
    description_html STRING,
    priority STRING,
    start_date DATE,
    target_date DATE,
    student_id STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    plane_result STRING;
BEGIN
    SELECT cr
