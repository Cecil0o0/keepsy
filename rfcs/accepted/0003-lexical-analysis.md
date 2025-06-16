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

The basic concepts include loop block for every character and Finite-State-Machine struct for every lexeme. For more simplicity, I choose the Determinate-Finite-Automata to implement finite char-based state transition rather than Non-Determinate-Finite-Automata. First of the scan function, I initialize all the DFA structs symbol to prepare for reference; Secondly, in a while loop block, I strip whitespace, suspect every leading character for dispatching a DFA to try pass over following characters with a temporary pointer, sum with the prior pointer if state transition succeed otherwise drop it, do a backtracking when necessary.

Evaluation is a short but necessary post-scan stage to evaluating a scanned lexeme to be a lexical token which is known by parser, evaluated category of token falls into a common set with several elements including identifier, keyword, punctuator, literal, comment, whitespace.

A issue is what if encounter a case that a DFA try fails, is it a necessary control flow for transfering to another DFA, and if yes what's next proper candidate, or else just return an error with friendly message? For performance perspective, returning error is the better choice because less resource of hardware would be used while may lose a change for a potential candidate. To enumerate all cases is a choice for both performance and function.

## Unresolved Questions

Unresolved Questions:
- Is it necessary to lex all SQL syntax for a data storage software? It is a very large amount of work.
