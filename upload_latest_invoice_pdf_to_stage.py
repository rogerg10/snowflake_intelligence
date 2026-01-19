"""
All data and identifiers used by this example are dummy and for demonstration only.

Utility script for Snowflake Notebooks / Snowpark:
- Reads the latest base64-encoded invoice PDF from ADMISSIONS_INTELLIGENCE.DATA.TMP_INVOICE_PDF_STAGE
- Writes it to a local /tmp path inside the Snowflake compute container
- Uploads the PDF into the INVOICE_PDF_STAGE stage for downstream use

Note: This script is logically related to the Snowflake notebook
ADMISSIONS_INTELLIGENCE.DATA."Invoice Generator", which is executed by the
GENERATE_AND_STORE_INVOICE procedure in the database.
"""

from snowflake.snowpark.context import get_active_session
import base64

# Get the active Snowpark session (provided automatically in Snowflake Notebooks)
session = get_active_session()

# Retrieve the most recent invoice and its base64-encoded PDF from the temp table
df = session.sql(
    """
    SELECT invoice_number, pdf_base64
    FROM ADMISSIONS_INTELLIGENCE.DATA.TMP_INVOICE_PDF_STAGE
    ORDER BY created_at DESC
    LIMIT 1
    """
)

row = df.collect()[0]
invoice_number = row[0]
pdf_base64 = row[1]

# Decode the base64 string into raw PDF bytes
pdf_bytes = base64.b64decode(pdf_base64)

# Write the PDF to a temporary local path in the container
local_path = f"/tmp/{invoice_number}.pdf"
with open(local_path, "wb") as f:
    f.write(pdf_bytes)

# Upload the PDF file into the target stage for long-term storage
stage_path = f"@ADMISSIONS_INTELLIGENCE.DATA.INVOICE_PDF_STAGE/{invoice_number}.pdf"
session.file.put(local_path, stage_path, overwrite=True)

print(f"✅ PDF generated and uploaded to: {stage_path}")
