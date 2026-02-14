# A columnar data file format

Let's started with the concept of file. A file is a named collection of data stored on a computer's storage device (e.g., hard drive, SSD) that represents information in a structured format.

For example, a '.txt' file collects human-readable characters without any formating, also called 'plain text', which is typically contains unstructured or minimally constructured data such as notes, novels, contracts, legal provisions. With that format, we could easily read lines or paragraphs for receiving useful information, but it could be storaged but not be suitable for retrievals(many problems if you do), thus we need a constructed format prepared to do data analysis based on retrievals or even accquire a insight, an general advanced requirements by people.

We need a file format that can facilitate advanced analytics with scalable cost-efficiency retrievals.

## Rationale and Alternatives

- Relational Storage(SQL)
  - Row-oriented Storage
    - an [InnoDB](https://en.wikipedia.org/wiki/InnoDB) file format for file-per-table in Mysql database.
    - [Apache Avro](https://en.wikipedia.org/wiki/Apache_Avro) is a row-oriented remote procedure call and data serialization framework developed within Apache's Hadoop project
  - Column-oriented Storage
    - [Apache Parquet](https://en.wikipedia.org/wiki/Apache_Parquet) is an open source, column-oriented data file format designed for efficient data storage and retrieval.
    - [Apache ORC](https://en.wikipedia.org/wiki/Apache_ORC) is the smallest, fastest columnar storage for Hadoop workloads.
    - [Apache Arrow](https://en.wikipedia.org/wiki/Apache_Arrow) is a universal columnar format and multi-language toolbox for fast data interchange and in-memory analytics.
- Non-relational Storage(NoSQL)
  - Document-oriented data file format.
    - [BSON](https://en.wikipedia.org/wiki/BSON) file format in MongoDB database.
