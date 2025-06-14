# A rule-based program which performs lexical tokenization

This is a classic lexer forms the first phase of a compiler or interpreter frontend in processing source code.

## Motivation

Data are a collection of discrete or continuous values, data with a predefined two-dimension structure is a common usage for describing and storing business system data, Structure Query Language (SQL) is a standard language for accessing and manipulating databases used by most relational database management systems (RDBMS), every business system backend developer are using the SQL to do their business.

Lexical tokenization is conversion of a text into (semantically or syntactically) meaningful lexical tokens belonging to categories defined by a "lexer" program, which is the first step of compiling or interpreting an application program described by backend developers. For a storage software, it's one of the important necessary component for foundation of data storage.

## Retionale and Alternatives

There could be some alternatives in library or executable file format for speeding up implementation of lexical analysis, but we choose first to use Zig programming language for its simplicity and maintainability, while we also could keep the choice as a backup.

## Implementation

We breakdown the lexical analysis into three parts:
- A `tokenizer` module is responsible for lexical tokenization, which exports a functionality to process a string to scan in one pass and then give back an evaluations of tokens based on the `evaluator` module.
- A `evaluator` module is doing evaluating in the post-scan stage, which exports a functionality for recognizing and categorizing the lexemes into tokens that consists of a required category name and an optional value.
- A `lexer` module as facade module is a combination of the `tokenizer` and `evaluator` modules, which exports a functionality for lexical analysis, and then re-export a `lex` function.

The basic concepts include loop block for every character and Finite-State-Machine struct for every lexeme. For more simplicity, I choose the Determine-Finite-Automata to implement finite char-based state transition rather than Non-Determine-Finite-Automata. First of the scan function, I will initialize all the DFA structs to stand by.

## Unresolved Questions

Unresolved Questions:
- Is it necessary to lex all SQL syntax for a data storage software? It is a very large amount of work.
