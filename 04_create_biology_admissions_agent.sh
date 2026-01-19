
# -----------------------------
# Environment variables
# -----------------------------

# Snowflake database that stores your agents
export DATABASE_NAME="SNOWFLAKE_INTELLIGENCE"

# Base URL for your Snowflake account (update to your own)
export SNOWFLAKE_ACCOUNT_BASE_URL="https://xxxxx-xxxxxx.snowflakecomputing.com"

# Schema where the agent will live
export SCHEMA_NAME="AGENTS"

# Personal access token (PAT) for the Intelligence API
export INTELLIGENCE_AGENT="XXXX"



# -----------------------------
# Create a new Intelligence Agent
# -----------------------------

curl -X POST "$SNOWFLAKE_ACCOUNT_BASE_URL/api/v2/databases/$DATABASE_NAME/schemas/$SCHEMA_NAME/agents" \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --header "Authorization: Bearer $INTELLIGENCE_AGENT" \
  --data '{
    "name": "ADMISSIONS_INTELLIGENCE_NEW_2026",
    "comment": "This agent supports Admissions in analyzing admissions data using Cortex Analyst and coordinating several related operations.",
    "models": {
      "orchestration": "claude-4-sonnet"
    }
  }'



# -----------------------------
# Configure agent profile, instructions, tools, and tool resources
# -----------------------------

curl -X PUT "$SNOWFLAKE_ACCOUNT_BASE_URL/api/v2/databases/$DATABASE_NAME/schemas/$SCHEMA_NAME/agents/ADMISSIONS_INTELLIGENCE_NEW_2026" \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --header "Authorization: Bearer $INTELLIGENCE_AGENT" \
  --data '{
    "profile": {
      "display_name": "Biology Admissions Agent"
    },    
    "instructions": {
      "response": "You are a specialized academic operations agent for Biology admissions. Your role is to help users query, onboard, and invoice students efficiently using Snowflake-managed data. When handling requests, always base actions on precise user intent and current database context. Respond with schema-qualified SQL, procedural calls, or stepwise actions as dictated by the workflow, and never use SELECT * except when specifically asked. Include a two-sentence summary of each query or action, focused on data effect or next steps only. Always use the exact column and table names, including workflow flags like onboardingstarted and invoicingstarted. Avoid commentary on admissions policy, academic judgment, or analysis outside the scope of structured data and defined processes. Never speculate; only draw conclusions that are directly supported by the data. Answers should be concise, technically accurate, logically sequenced, and tailored for users familiar with admissions operations.",
      "sample_questions": [
        {
          "question": "Give me a list of all the domestic applicants for the masters of science in Botany"
        },
        {
          "question": "What are the upcoming deadlines for applications?"
        }
      ]
    },
    "tools": [
      {
        "tool_spec": {
          "type": "generic",
          "name": "onboard_user_and_update",
          "description": "Trigger this tool to commence or initiate the onboarding process for one or more students/applicants. On command (\"initiate onboarding\", \"commence onboarding\", or similar phrases, including pluralized forms), look for any student or applicant name, studentid, or context in the conversation to determine who should be onboarded. For multiple names/entities, apply the function in parallel to all referenced students or applicants. Auto-populate parameters based on the latest relevant applicant/student, selecting from either direct user reference or the last entity mentioned by the agent or user.",
          "input_schema": {
            "type": "object",
            "properties": {
              "description_html": {
                "type": "string",
                "description": "Concatenate the following values as follows \"Student ID - Student First Name + Student Last Name - Program Name\" where: Student ID = Student ID of the latest student or student referenced in the conversation. Student First Name + Student Last Name = Student First Name followed by a blank space followed by Student Last Name, of the latest student referenced in the conversation. Program Name = The Program Name of the latest student or student referenced in the conversation."
              },
              "item_name": {
                "type": "string",
                "description": "Always \"Create Campus Access - New -\" followed by a space, and then the Student ID of the latest student(s) or student referenced in the conversation."
              },
              "priority": {
                "type": "string",
                "description": "Always medium"
              },
              "start_date": {
                "type": "string",
                "description": "Retrieve the field \"CONFIRMATION_DATE\" for that student"
              },
              "student_id": {
                "type": "string",
                "description": "Retrieve the field \"STUDENT_ID\" for that student"
              },
              "target_date": {
                "type": "string",
                "description": "Retrieve the field \"EXPECTED_START_DATE\" for that student"
              }
            },
            "required": [
              "description_html",
              "item_name",
              "priority",
              "start_date",
              "student_id",
              "target_date"
            ]
          }
        }
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "generate_and_store_invoice",
          "description": "Trigger this tool to create or generate an invoice for one or more students/applicants. When user uses phrases like \"create invoice\", \"generate invoice\", or similar, refer to conversation context for the most recently referenced student/applicant(s). Trigger for all relevant individuals if the request is plural. Automatically fill in required parameters using the student/applicant details from context and table data.",
          "input_schema": {
            "type": "object",
            "properties": {
              "item_name": {
                "type": "string",
                "description": "always: University of Freedonia - Admissions Deposit - 15% of total tuition fees"
              },
              "notes": {
                "type": "string",
                "description": "Use the field notes from the table ADMISSIONS_INTELLIGENCE.DATA.FINANCIAL_RECORDS for that student"
              },
              "amount_paid": {
                "type": "number",
                "description": "Use the field unit_cost from the table ADMISSIONS_INTELLIGENCE.DATA.FINANCIAL_RECORDS for that student"
              },
              "due_date": {
                "type": "string",
                "description": "30 days from today’s date"
              },
              "from_name": {
                "type": "string",
                "description": "Always \"University of Freedonia - Admissions\""
              },
              "invoice_number": {
                "type": "string",
                "description": "Use the field invoice_number from the table ADMISSIONS_INTELLIGENCE.DATA.FINANCIAL_RECORDS for that student"
              },
              "quantity": {
                "type": "number",
                "description": "Always 1"
              },
              "ship_to": {
                "type": "string",
                "description": "Use the field email from the table BIOLOGY_ADMISSIONS_DB.INTAKE_2025_26.CONFIRMED_APPLICANTS for that student"
              },
              "student_id": {
                "type": "number",
                "description": "Use the field student_id from the table ADMISSIONS_INTELLIGENCE.DATA.FINANCIAL_RECORDS for that student"
              },
              "currency": {
                "type": "string",
                "description": "Use the field currency from the table ADMISSIONS_INTELLIGENCE.DATA.FINANCIAL_RECORDS for that student"
              },
              "invoice_date": {
                "type": "string",
                "description": "Today’s date"
              },
              "shipping": {
                "type": "number",
                "description": "Always 1"
              },
              "tax": {
                "type": "number",
                "description": "Calculate 15% of the field amount from the table ADMISSIONS_INTELLIGENCE.DATA.FINANCIAL_RECORDS for that student"
              },
              "terms": {
                "type": "string",
                "description": "First look up the field PAYMENT_TERMS from the table ADMISSIONS_INTELLIGENCE.DATA.FINANCIAL_RECORDS for that student, and then replace the text [PAYMENT_TERMS] from this sentence \"Net [PAYMENT_TERMS]: Payment due [PAYMENT_TERMS] days from invoice date\", and return the updated sentence"
              },
              "to_name": {
                "type": "string",
                "description": "name of the applicant or student referenced in the conversation."
              },
              "payment_terms": {
                "type": "string",
                "description": "Always \"Net 30: Payment due 30 days from invoice date\""
              }
            },
            "required": [
              "item_name",
              "notes",
              "amount_paid",
              "due_date",
              "from_name",
              "invoice_number",
              "quantity",
              "ship_to",
              "student_id",
              "currency",
              "invoice_date",
              "shipping",
              "tax",
              "terms",
              "to_name",
              "payment_terms"
            ]
          }
        }
      },
      {
        "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "CONFIRMED_APPLICANTS",
          "description": "Semantic model for CONFIRMED_APPLICANTS and FINANCIAL_RECORDS used by Cortex Analyst for Biology admissions."
        }
      }
    ],
    "tool_resources": {
      "onboard_user_and_update": {
        "type": "procedure",
        "identifier": "BIOLOGY_ADMISSIONS_DB.INTAKE_2025_26.CREATE_ISSUE_AND_UPDATE_ONBOARDING",
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "COMPUTE_WH"
        }
      },
      "generate_and_store_invoice": {
        "type": "procedure",
        "identifier": "BIOLOGY_ADMISSIONS_DB.INTAKE_2025_26.GENERATE_AND_STORE_INVOICE",
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "COMPUTE_WH"
        }     
      },
      "CONFIRMED_APPLICANTS": {
        "semantic_model_file": "@BIOLOGY_ADMISSIONS_DB.INTAKE_2025_26.BIOLOGY_DOCS_STAGE/biology_confirmed_applicants.yaml",
        "execution_environment": {
          "type": "warehouse",
          "query_timeout": 60
        }
      }
    }
  }'



# -----------------------------
# Retrieve and inspect final agent spec (sanity check)
# -----------------------------

curl -X GET "$SNOWFLAKE_ACCOUNT_BASE_URL/api/v2/databases/$DATABASE_NAME/schemas/$SCHEMA_NAME/agents/ADMISSIONS_INTELLIGENCE_NEW_2026" \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --header "Authorization: Bearer $INTELLIGENCE_AGENT" | jq .
