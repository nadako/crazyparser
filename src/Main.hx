import Sys.println;

class Main {
    static function main() {
        var src = sys.io.File.getContent("Test.hx");
        var parser = new Parser(src);

        var decls = parser.parse();

        for (decl in decls) {
            println('${decl.kind.getName()} ${decl.pos}');
            switch (decl.kind) {
                case NClassDecl(cls):
                    printToken(cls.classKeyword);
                    printToken(cls.name);
                    printToken(cls.openBrace);
                    printToken(cls.closeBrace);
                case NImportDecl(imp):
                    printToken(imp.importKeyword);
                    printToken(imp.identifier);
                    printToken(imp.semicolon);
            }
        }
    }

    static function printToken(token:Token) {
        println('\t$token');
        if (token.leadTrivia != null) {
            for (trivia in token.leadTrivia)
                println('\t\tLEAD: $trivia');
        }
        if (token.trailTrivia != null) {
            for (trivia in token.trailTrivia)
                println('\t\tTRAIL: $trivia');
        }
    }
}
