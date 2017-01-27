import Sys.println;

class Main {
    static function main() {
        var src = sys.io.File.getContent("Test.hx");
        var parser = new Parser(src);
        var root = parser.parse();

        function printToken(token:Token) {
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


        switch (root.kind) {
            case NClassDecl(cls):
                println('NClassDecl ${root.pos}');
                printToken(cls.classKeyword);
                printToken(cls.name);
                printToken(cls.openBrace);
                printToken(cls.closeBrace);
        }
    }
}
