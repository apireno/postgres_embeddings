#!/bin/bash

# PostgreSQL connection details. Adjust these if your setup is different.
DB_NAME="vector_demo_db"
DB_USER="postgres" # Default PostgreSQL superuser. Change if you have a different user.
DB_HOST="localhost"
DB_PORT="5432"
export PGPASSWORD=root

# --- 1. Database Setup ---
echo "--- Setting up database: $DB_NAME ---"

# Drop and recreate the database to ensure a clean slate.
echo "Dropping existing database '$DB_NAME' if it exists..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "DROP DATABASE IF EXISTS $DB_NAME;" > /dev/null 2>&1

echo "Creating database '$DB_NAME'..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;" > /dev/null 2>&1
echo "Database '$DB_NAME' created."

echo "Creating the pgvector extension..."
# Connect to the newly created database and create the extension.
# Using IF NOT EXISTS prevents errors if it somehow already exists.
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS vector;" > /dev/null 2>&1
echo "pgvector extension created."

# Connect to the newly created/existing database and execute DDL from db/ddl.sql.
echo "--- Loading DDL from db/ddl.sql ---"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f db/ddl.sql > /dev/null 2>&1
echo "DDL loaded."

# Load all PL/pgSQL functions from the 'db/functions.sql' file.
echo "--- Loading functions from db/functions.sql ---"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f db/functions.sql > /dev/null 2>&1
echo "Functions loaded."

# --- 2. Upload Embedding Data ---
echo "--- Uploading embedding data from db/sample_embedding_model.txt ---"

# Clear existing data from the 'embedding' table to prevent primary key conflicts on re-run.
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "TRUNCATE TABLE embedding RESTART IDENTITY;" > /dev/null 2>&1

# Count total lines for the progress counter
TOTAL_EMBEDDING_LINES=$(wc -l < db/sample_embedding_model.txt)
CURRENT_EMBEDDING_LINE=0

# Read 'db/sample_embedding_model.txt' line by line.
# Each line is expected to be "word coeff1 coeff2 coeff3 ..."
while IFS= read -r line || [[ -n "$line" ]]; do # '|| [[ -n "$line" ]]' handles the last line if it doesn't end with a newline
    ((CURRENT_EMBEDDING_LINE++))
    printf "\rProcessing embedding row %d of %d..." "$CURRENT_EMBEDDING_LINE" "$TOTAL_EMBEDDING_LINES"

    # Use awk to extract the first word and the rest of the line (coefficients).
    word=$(echo "$line" | awk '{print $1}')
    # Replace spaces with commas and remove leading space for valid float[] array format.
    coeffs=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ //; s/ /,/g')

    # Only attempt insert if both word and coefficients are present.
    if [[ -n "$word" && -n "$coeffs" ]]; then
        # Construct the SQL INSERT statement.
        # Single quotes within the word need to be escaped by doubling them (e.g., 'O''Reilly').
        ESCAPED_WORD=$(echo "$word" | sed "s/'/''/g")
        INSERT_SQL="INSERT INTO embedding (word, embedding) VALUES ('$ESCAPED_WORD', '[$coeffs]');"
        
        # Execute the INSERT statement using psql, suppressing output.
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$INSERT_SQL" > /dev/null 2>&1
    fi
done < db/sample_embedding_model.txt
printf "\nEmbedding data uploaded. (%d rows)\n" "$CURRENT_EMBEDDING_LINE"
