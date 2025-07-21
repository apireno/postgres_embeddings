#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
DB_NAME="vector_demo_db"
DB_USER="postgres"
DB_HOST="localhost"
DB_PORT="5432"
export PGPASSWORD=root

# File path for the sample content
CONTENT_SRC_FILE="db/sample_content.csv"


# --- 3. Upload Sample Content and Calculate Embeddings ---
echo "--- Bulk uploading content from '$CONTENT_SRC_FILE' and calculating embeddings ---"

# Use a psql heredoc for a clean, multi-line, and efficient command
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<-EOSQL

    -- Clear existing data from the final table
    TRUNCATE TABLE sample_content RESTART IDENTITY;

    -- Step 1: Create a temporary staging table to hold the raw content.
    -- This table is automatically dropped at the end of the session.
    CREATE TEMP TABLE content_stage (content TEXT);

    -- Step 2: Use \COPY to bulk load the content file into the staging table.
    -- This is significantly faster than a one-by-one insert.
    \COPY content_stage(content) FROM '$CONTENT_SRC_FILE' WITH (FORMAT text);

    -- Step 3: In a single transaction, insert into the final table by selecting
    -- from the staging table and calling the function for each row.
    INSERT INTO sample_content (content, embedding)
    SELECT
        content,
        "demo_content_to_vector"(content)
    FROM
        content_stage;

EOSQL


# --- 4. Verification ---
ROW_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM sample_content;")

# xargs trims whitespace from the psql output
echo
echo "✅ Success! Bulk loaded and processed $(echo $ROW_COUNT | xargs) content rows."
echo

# --- 5. Prompt User for Input and Execute Vector Search ---
echo "Script finished."
