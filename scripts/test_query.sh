#!/bin/bash

# PostgreSQL connection details. Adjust these if your setup is different.
DB_NAME="vector_demo_db"
DB_USER="postgres" # Default PostgreSQL superuser. Change if you have a different user.
DB_HOST="localhost"
DB_PORT="5432"
export PGPASSWORD=root

# Prompt the user to enter a sentence.
read -p "Enter a sentence for vector search: " USER_INPUT_SENTENCE

# Escape single quotes in user input for safe SQL execution.
ESCAPED_USER_INPUT=$(echo "$USER_INPUT_SENTENCE" | sed "s/'/''/g")

echo "--- Executing vector search for: \"$USER_INPUT_SENTENCE\" ---"

# Execute the vector similarity search query.
# We calculate the embedding of the user input using 'demo_content_to_vector' once.
# Then, we use the '<->' operator (L2 distance) from pgvector to find the closest embeddings.
# The result is ordered by distance (smallest distance means highest similarity) and limited to 10.
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF
    
    SELECT
        id,
        content,
        embedding <-> "demo_content_to_vector"('$ESCAPED_USER_INPUT')::vector AS distance
    FROM
        sample_content
    ORDER BY
        distance
    LIMIT 10;
EOF

echo "Script finished."