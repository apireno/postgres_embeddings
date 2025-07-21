# README.md

# Postgres Embeddings: On-the-Fly Sentence Embeddings in Your Database

This repository demonstrates how to store word embedding models directly within a PostgreSQL database and generate sentence embeddings on the fly. This approach allows you to perform powerful semantic searches and other NLP tasks without needing to move your data or manage a separate vector search service.

-----

## 🎯 Goal

The primary goal of this project is to show how you can:

  * Store word embedding models in database tables.
  * Calculate sentence embeddings for text blobs in real time.
  * Leverage the power of `pgvector` for efficient similarity searches at scale.

-----

## ✨ Features

  * **pgvector Integration**: Installs and configures the `pgvector` extension for PostgreSQL.
  * **Database Setup**: Creates a dedicated database (`vector_demo_db`) for the demonstration.
  * **Custom SQL Functions**:
      * `demo_mean_vector`: Calculates the mean vector of a set of word vectors.
      * `demo_generate_edgengrams`: Handles out-of-vocabulary (OOV) words using n-grams.
      * `demo_get_sentence_vectors`: Retrieves vectors for a given blob of text.
      * `demo_content_to_vector`: Returns a representative mean vector for a blob of text.
  * **Sample Data**: Random movie review content and the embeddings are expected to be GloVe pre-trained 6B 50 token model (glove.6B.50d.txt).

-----

## ⚙️ How It Works

The core idea is to treat your word embedding model as data. Each word and its corresponding vector are stored in a table. When you want to find the embedding for a sentence, a SQL function processes the text, looks up the vectors for each word, and calculates a representative vector for the entire sentence (in this case, by averaging the word vectors).

By using a **HNSW (Hierarchical Navigable Small World) index**, the similarity search can be performed with high speed and accuracy, even on large datasets.

-----

## 🚀 Setup and Usage

To get started, run the following scripts in order:

1.  **`setup_pgvector`**: This script will install the `pgvector` extension to your PostgreSQL database.

2.  **`setup_db_and_upload`**: This script will:

      * Create the `vector_demo_db` database.
      * Create the necessary tables.
      * Define the custom SQL functions.
      * Upload the sample word embedding model to a table.

3.  **`upload_sample_data`**: This script will upload the sample content (a list of firms from the SEC) into the `sample_content` table.

4.  **`test_query`**: This script will run a sample query to demonstrate a similarity search.

-----

## 🔍 Example Query

The following query demonstrates how to find the 10 most similar content entries to a user-provided input string. The `<->` operator is the Euclidean distance operator from `pgvector`.

```sql
SELECT
    id,
    content,
    embedding <-> "demo_content_to_vector"('$ESCAPED_USER_INPUT')::vector AS distance
FROM
    sample_content
ORDER BY
    distance
LIMIT 10;
```

For example if using the movie sample and the term "dogs and cats" you should get the following results:

```
  id   |                content                |      distance      
-------+---------------------------------------+--------------------
 38814 | "he also chases cats                  |  1.126358589416041
 57057 | "why aren't they "" dog animals "" ?" | 1.2264580651791586
 56839 | "the animals themselves               | 1.2694676309930952
 40272 | "they're these octopus men            | 1.3394634719230951
 34447 | "i love animals                       | 1.4022585702172772
 33552 | "that's some ape . """                | 1.4305203206106698
 35264 | "they even have animals               | 1.4411370250826556
 19463 | "ghost dog lives                      | 1.4886350836870779
 42335 | humans .                              | 1.5341574644813925
 49885 | "they are not creatures               |  1.539828656808244
(10 rows)

```


-----

## 🔧 Customization

You can easily adapt this repository to use your own word embedding models and text data. For example, you could:

  * Upload a **GloVe model** instead of the provided fastText model.
  * Use **IMDb movie reviews** as your text content.

To do this, you would need to modify the `setup_db_and_upload` and `upload_sample_data` scripts to handle your specific data formats.

-----

## 🙏 References and Thank Yous

  * **pgvector**: [https://github.com/pgvector/pgvector](https://github.com/pgvector/pgvector)
  * **fastText**: [https://fasttext.cc/](https://fasttext.cc/)
  * **GloVe**: [https://nlp.stanford.edu/projects/glove/](https://nlp.stanford.edu/projects/glove/)

  

A big thank you to the creators and maintainers of these powerful open-source tools\!
