#!/bin/bash

# PostgreSQL connection details. Adjust these if your setup is different.
DB_NAME="vector_demo_db"
DB_USER="postgres" # Default PostgreSQL superuser. Change if you have a different user.
DB_HOST="localhost"
DB_PORT="5432"
export PGPASSWORD=root

# --- 3. Upload Sample Content and Calculate Embedding ---
echo "--- Uploading sample content from db/sample_content.csv and calculating embeddings ---"

# Clear existing data from the 'sample_content' table.
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "TRUNCATE TABLE sample_content RESTART IDENTITY;" > /dev/null 2>&1

# Count total lines for the progress counter
TOTAL_CONTENT_LINES=$(wc -l < db/sample_content.csv)
CURRENT_CONTENT_LINE=0

# Read 'db/sample_content.csv' line by line.
# Each line is expected to be a single text string.
while IFS= read -r line || [[ -n "$line" ]]; do
    ((CURRENT_CONTENT_LINE++))
    printf "\rProcessing content row %d of %d..." "$CURRENT_CONTENT_LINE" "$TOTAL_CONTENT_LINES"

    # Escape single quotes in the content text for SQL insertion.
    content_text=$(echo "$line" | sed "s/'/''/g")

    if [[ -n "$content_text" ]]; then
        # Construct the SQL INSERT statement.
        # Call 'fn::content_to_vector' directly in the INSERT statement to calculate the embedding.
        # Cast the result to 'vector' type as demo_content_to_vector returns float[].
        INSERT_SQL="INSERT INTO sample_content (content, embedding) VALUES ('$content_text', \"demo_content_to_vector\"('$content_text'));"
        
        # Execute the INSERT statement, suppressing output.
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$INSERT_SQL" > /dev/null 2>&1
    fi
done < db/sample_content.csv
printf "\nSample content uploaded and embeddings calculated. (%d rows)\n" "$CURRENT_CONTENT_LINE"

# --- 4. Prompt User for Input and Execute Vector Search ---
echo ""

echo "Script finished."