
-- Create the 'embedding' table to store words and their associated vectors.
-- This table will have two columns:
-- 'word': Stores the string representation of the word, serving as the primary key.
-- 'embedding': Stores the vector representation of the word, using the 'vector' type from pgvector.
CREATE TABLE embedding (
    word TEXT PRIMARY KEY,          -- 'TEXT' is a common and flexible string type in PostgreSQL
    embedding vector                -- 'vector' type from the pgvector extension
);

-- Create an index on the 'word' column.
-- This index will improve the performance of lookups and joins based on the 'word' column.
CREATE INDEX idx_embedding_word ON embedding (word);


CREATE TABLE sample_content (
    id bigserial PRIMARY KEY,
    content TEXT,          -- 'TEXT' is a common and flexible string type in PostgreSQL
    embedding vector(50)                -- 'vector' type from the pgvector extension
);

CREATE INDEX ON sample_content USING hnsw (embedding vector_l2_ops);
