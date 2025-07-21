

-- Function to calculate the mean (average) of an array of vectors.
-- This is a crucial helper for handling OOV words by averaging their n-gram embeddings.

CREATE OR REPLACE FUNCTION demo_mean_vector(vectors vector[])
 RETURNS vector
 LANGUAGE plpgsql
AS $function$
DECLARE
    normalized_vectors vector[];       -- Stores the vectors after normalization, now as pgvector type
    num_input_vectors int := 0;        -- Count of valid, non-NULL input vectors
    vector_dimension int := -1;        -- The dimension (N) of the 1xN vectors
    sum_vector vector;                 -- Stores the sum of elements at each position, now as pgvector type
    mean_vec vector;                   -- The final mean vector, now as pgvector type
    current_vector vector;            -- Temporary variable for iterating through input float arrays
BEGIN
    -- --- DEBUG NOTICES START ---
    -- RAISE NOTICE '--- demo_mean_vector called ---';
    -- RAISE NOTICE 'Input vectors_array (raw): %', vectors;
    -- RAISE NOTICE 'array_length(vectors, 1) (initial check): %', array_length(vectors, 1);
    IF array_length(vectors, 1) IS NOT NULL AND array_length(vectors, 1) > 0 THEN
        -- RAISE NOTICE 'vectors[0] value: %', vectors[0];
        -- RAISE NOTICE 'vectors[0] IS NULL: %', (vectors[0] IS NULL);
    END IF;
    -- --- DEBUG NOTICES END ---

    -- 1. Handle cases where the input is NULL or an empty array
    IF vectors IS NULL OR array_length(vectors, 1) IS NULL OR array_length(vectors, 1) = 0 THEN
        -- RAISE NOTICE 'Returning NULL: Input array is NULL or empty.';
        RETURN NULL;
    END IF;

    
    -- 2. Iterate through the input 'vectors' array
    --    - Filter out any NULL sub-arrays (vectors)
    --    - Convert to pgvector type and normalize each valid vector
    --    - Determine the common dimension (N) of the vectors
    FOREACH current_vector IN ARRAY vectors LOOP
        normalized_vectors := array_append(normalized_vectors, l2_normalize(current_vector));
        num_input_vectors := num_input_vectors + 1;
    END LOOP;



    -- If no valid normalized vectors were found, return NULL
    IF num_input_vectors = 0 THEN
        -- RAISE NOTICE 'Returning NULL: No valid normalized vectors found.';
        RETURN NULL;
    END IF;

    -- 3. Sum up the normalized vectors
    -- Initialize sum_vector with the first normalized vector
    sum_vector := normalized_vectors[1];

    -- Add remaining normalized vectors to sum_vector
    FOR i IN 2..num_input_vectors LOOP
        sum_vector := sum_vector + normalized_vectors[i];
    END LOOP;

    -- RAISE NOTICE 'Returning sum_vector: %', sum_vector;
    RETURN sum_vector;
    -- 4. Calculate the mean vector
    -- Divide the sum_vector by the total number of normalized input vectors
    mean_vec := array(select unnest(sum_vector::real[]) / num_input_vectors)::vector;

    -- RAISE NOTICE 'Returning mean_vec: %', mean_vec;
    -- Return the final calculated mean vector as a float array
    RETURN mean_vec;
END;
$function$
;




-- Function to generate edge n-grams (prefixes) from a given text.
-- This simulates the 'edgengram(min_len, max_len)' filter.
-- It takes the input text, a minimum length for the n-gram, and a maximum length.
-- It returns an array of text, where each element is an edge n-gram.
CREATE OR REPLACE FUNCTION demo_generate_edgengrams(
    input_text TEXT,
    min_len INT DEFAULT 2,
    max_len INT DEFAULT 10
)
RETURNS TEXT[] AS $$
DECLARE
    ngrams TEXT[] := '{}'; -- Initialize an empty array to store the n-grams
    current_len INT;       -- Loop counter for n-gram length
    text_len INT;          -- Length of the input text
BEGIN
    -- Handle NULL or empty input text
    IF input_text IS NULL OR input_text = '' THEN
        RETURN '{}';
    END IF;

    text_len := LENGTH(input_text);

    -- Ensure min_len and max_len are valid
    IF min_len < 1 THEN
        min_len := 1;
    END IF;
    IF max_len < min_len THEN
        max_len := min_len;
    END IF;

    -- Loop from min_len up to max_len or the length of the input text, whichever is smaller
    FOR current_len IN min_len .. LEAST(max_len, text_len) LOOP
        -- Extract the prefix of the current_len and add it to the ngrams array
        ngrams := array_append(ngrams, SUBSTRING(input_text, 1, current_len));
    END LOOP;

    RETURN ngrams;
END;
$$ LANGUAGE plpgsql IMMUTABLE; 

-- Function to retrieve vectors for an input sentence, mirroring the SurrealDB logic.
-- It tokenizes the sentence by splitting it, looks up each token's embedding.
-- If a token is Out-Of-Vocabulary (OOV), it generates n-grams for it (using demo_generate_edgengrams),
-- retrieves embeddings for those n-grams, and calculates their mean vector.
-- This function relies on:
--   - 'demo_generate_edgengrams' (for generating prefixes/n-grams from OOV words)
--   - 'demo_mean_vector' (for averaging collected n-gram embeddings)

CREATE OR REPLACE FUNCTION demo_get_sentence_vectors(
    input_text TEXT
)
RETURNS vector[] -- Changed return type from TEXT to vector[]
AS $$
DECLARE
    -- Array to store the final embeddings for all tokens in the sentence
    -- Changed from float[][] to vector[]
    all_sentence_vectors vector[];
    raw_tokens TEXT[];                 -- Array to store tokens after splitting the input text
    current_raw_token TEXT;            -- The raw string of the current token before normalization
    current_word TEXT;                 -- The normalized (lowercase) string representation of the current token
    word_embedding vector;             -- The embedding for the current token (if found directly in 'embedding' table)
    oov_ngrams TEXT[];                 -- Array of n-grams generated for an OOV token
    ngram_word TEXT;                   -- Individual n-gram string from the 'oov_ngrams' array
    ngram_embedding vector;            -- Embedding for an individual n-gram
    -- Temporary array to store embeddings of n-grams for a single OOV token
    -- Changed from float[][] to vector[]
    collected_ngram_embeddings vector[];
    -- The calculated mean vector for an OOV token's n-grams
    -- Changed from float[] to vector (assuming demo_mean_vector returns a single vector)
    mean_oov_vector vector;
BEGIN
    -- Initialize the result array for all sentence vectors as an empty vector array
    all_sentence_vectors := '{}'::vector[];

    -- Tokenize the input text by splitting it on whitespace.
    -- This replaces the functionality of 'large_name_analyzer' for tokenization.
    -- We use regexp_split_to_array to handle multiple spaces and trim empty strings.
    raw_tokens := regexp_split_to_array(input_text, '\s+');

    -- Iterate through each raw token obtained from splitting the input text.
    FOREACH current_raw_token IN ARRAY raw_tokens LOOP
        -- Normalize the current token by converting it to lowercase and trimming whitespace.
        -- This replaces the normalization (lowercase, ascii) previously done by 'large_name_analyzer'.
        current_word := LOWER(TRIM(current_raw_token));

        -- Skip if the token is empty or NULL after processing (e.g., if only whitespace was present)
        IF current_word IS NULL OR current_word = '' THEN
            CONTINUE;
        END IF;

        -- 1. Attempt to retrieve the embedding directly from the 'embedding' table for the current word.
        -- Words in the 'embedding' table are assumed to be stored in lowercase due to previous DDL discussions.
        SELECT embedding INTO word_embedding
        FROM embedding
        WHERE word = current_word;

        -- 2. Process based on whether the word's embedding was found (In-Vocabulary - IV) or not (Out-Of-Vocabulary - OOV)
        IF word_embedding IS NOT NULL THEN
            -- If the word is In-Vocabulary, append its embedding to the result array.
            -- Removed explicit cast '::float[]' as all_sentence_vectors is now vector[]
            all_sentence_vectors := array_append(all_sentence_vectors, word_embedding);
        ELSE
            -- If the word is Out-Of-Vocabulary (OOV), generate its edge n-grams.
            oov_ngrams := demo_generate_edgengrams(current_word, 2, 10);

            -- Initialize a temporary array to collect embeddings of the generated n-grams.
            collected_ngram_embeddings := '{}'::vector[];

            -- Iterate through each generated n-gram.
            FOREACH ngram_word IN ARRAY oov_ngrams LOOP
                -- Attempt to retrieve the embedding for the current n-gram.
                -- N-grams are already lowercase from demo_generate_edgengrams.
                SELECT embedding INTO ngram_embedding
                FROM embedding
                WHERE word = ngram_word;

                -- If the n-gram has an embedding, add it to our collection.
                IF ngram_embedding IS NOT NULL THEN
                    collected_ngram_embeddings := array_append(collected_ngram_embeddings, ngram_embedding);
                END IF;
            END LOOP;
            -- If any n-gram embeddings were successfully collected, calculate their mean vector.
            IF array_length(collected_ngram_embeddings, 1) IS NOT NULL AND array_length(collected_ngram_embeddings, 1) > 0 THEN
                -- Call the 'demo_mean_vector' function to get the average embedding of the n-grams.
                -- Ensure demo_mean_vector returns a 'vector' type or is cast appropriately within that function.
                mean_oov_vector := demo_mean_vector(collected_ngram_embeddings);

                -- If a valid mean vector was returned (i.e., not NULL), append it to the sentence's vectors.
                -- Removed explicit cast '::float[]' as all_sentence_vectors is now vector[]
                IF mean_oov_vector IS NOT NULL THEN
                    all_sentence_vectors := array_append(all_sentence_vectors, mean_oov_vector);
                END IF;
            END IF;
        END IF;
    END LOOP;

    -- Return the final array of vectors for the input sentence.
    RETURN all_sentence_vectors;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION demo_content_to_vector(
    input_text TEXT
)
RETURNS vector AS $$
DECLARE
    sentence_vectors vector[]; -- Stores the array of vectors returned by demo_get_sentence_vectors
    content_demo_mean_vector vector; -- Stores the final mean vector for the entire content
BEGIN
    -- Call demo_get_sentence_vectors to get an array of vectors for all tokens in the input text.
    -- This function handles tokenization, IV/OOV lookup, and n-gram averaging for OOV words.
    sentence_vectors := demo_get_sentence_vectors(input_text);

    -- If demo_get_sentence_vectors returns NULL or an empty array (meaning no valid token vectors were found),
    -- then we cannot compute a meaningful content vector.
    IF sentence_vectors IS NULL THEN
        RETURN NULL; -- Equivalent to returning NONE in SurrealDB
    END IF;

    -- Calculate the mean vector of all collected token vectors.
    -- The 'demo_mean_vector' function handles cases where its input might be empty or invalid,
    -- returning NULL if no mean can be computed.
    content_demo_mean_vector := demo_mean_vector(sentence_vectors);

    -- Return the final mean vector for the entire content.
    -- If demo_mean_vector returned NULL (e.g., if all token vectors were invalid or empty),
    -- this function will also return NULL.
    RETURN content_demo_mean_vector;
END;
$$ LANGUAGE plpgsql;
