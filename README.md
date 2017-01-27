# crazyparser (forever WIP)

This is my attempt to write a parser for Haxe (and maybe in future "my own language") in a way the resulting AST preserves full fidelity
and provides ways to manipulate it so one could re-generate source code from changed AST, which is very useful for IDE support and
all kinds of refactoring and code formatting. The parser should also be as error-tolerant as possible, inserting missing expected nodes
where possible, because we want that AST to work while editing the file.

If something comes out of this, I hope to use it for the [Haxe Language Server](https://github.com/vshaxe/haxe-languageserver) to provide
advanced features, as well as for writing a decent Haxe code formatter.

This is heavily inspired by Microsoft's Roslyn and TypeScript parsers/AST structures.
