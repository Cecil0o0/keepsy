# Nativo
> The source of name is originated with a helpful AI thread at a normal night after large quantity of practices and exercises in a few years.

Nativo is a frontier build tool for any browser application with the Browser Native Behavior First Principle, written in zig, be tailored to browser part of any modern project, it's an implementation of [ECMAScript Language Specification: Scripts and Modules](https://tc39.es/ecma262/#sec-ecmascript-language-scripts-and-modules), Modules part takes the precedence.

Nativo has several advantages you may take attention to:
- Extremely fast linking, unidirectional linkage is done, bidirectional linkage could be an optional optimization.
  - module size is up to 1MiB for linkage, 1KiB import statements in one single module.
  - Nested imported can be resolved recursively in post-order traverse.
  - NamedImports and ImportedBinding can be resolved.
  - all non-exported statements are included and remained by default, code delimination when support DCE.
- [WIP]Handling symbol collision when modules have been unwrapped
- [WIP]Auto-Strip TypeScript Syntax
  - Typing notation for multiple literals in LexicalDeclaration
- [WIP]Support DCE

## Retionale
pros for module linkage:
- **Portable**. Collapse to one required deliverable while preserving module execution semantics, if no any optimization is performed.
- **Efficient**. interoperability inside module costs lower than inter-module operability.

cons for module linkage:
- **Scope Flattening**. No any modular knowledge and pattern preserved, linker composites all symbols into one scope if no any optimization is performed.
- **Symbol Collision**. A symbol is bound within a defined scope, module acts as a namespace that guarantees uniqueness. Linkage breaks that and may introduce collision on symbols that come from different modules.