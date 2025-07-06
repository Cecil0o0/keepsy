# About the Query module

A query language, also known as data query language or database query language (DQL), is a computer language used to make queries in databases and information systems. In database systems, query languages rely on strict theory to retrieve information. A well known example is the [Structured Query Language](https://en.wikipedia.org/wiki/SQL) (SQL).
查询语言，也叫数据查询语言或数据库查询语言，是一个计算机语言用于在数据库和信息系统中进行查询。在数据库系统中，查询语言依赖于严格理论知识来检索信息。知名例子是结构化查询语言。

## Types

Broadly, query languages can be classified according to whether they are **database query languages** or **information retrieval query languages**. The difference is that a database query language attempts to give factual questions, while an information retrieval query language attempts to find documents containing information that is relevant to an area of inquiry. Other types of query languages include:
广义上讲，查询语言可根据它们是否是数据库查询语言或信息检索查询语言来分类。区别是数据库查询语言尝试给予事实问题，而信息检索查询语言则试图寻找包含与查询领域相关信息的文档。其他类型的查询语言包括：

- Full-text. The simplest query language is treating all terms as bag of words that are to be matched with the postings in the inverted index and where subsequently ranking models are applied to retrieve the most relevant documents. Only tokens are defined in the CFG. Web search engines often use this approach.
全文本。最简单查询语言是把所有术语当成词包它与[倒排索引](https://en.wikipedia.org/wiki/Inverted_index)中的帖子匹配，并且在那里后续排名模型被应用去检索最相关文档。在 CFG 中定义的只是标记。网络搜索引擎通常使用此方法。
- Boolean. A query language that also supports the use of the Boolean operators AND, OR, and NOT.
布尔。也支持布尔运算符 AND、OR 和 NOT 的查询语言。
- Structured. A language that supports searching within (a combination of) fields when a document is structured and has been indexed using its document structure.
结构的。支持在字段（字段组合）中搜索时使用的语言，当文档结构化并使用其文档结构进行索引时。
- Natrual Language. A query language that supports natural language by parsing the natural language query to a form that can be best used to retrieve relevant documents, for example with Question answering systems or conversational search.
自然语言。一种支持自然语言的查询语言，通过将自然语言查询解析为一种最适合用以检索相关文档的形式，例如问答系统或对话式搜索。
