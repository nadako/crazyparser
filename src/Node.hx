class Node {
    public var kind:NodeKind;
    public var pos:Position;

    public function new() {}

    public function toString() {
        return '$kind $pos';
    }
}

enum NodeKind {
    NClassDecl(classDecl:ClassDecl);
    NImportDecl(importDecl:ImportDecl);
}

typedef ClassDecl = {
    var classKeyword:Token;
    var name:Token;
    var openBrace:Token;
    var closeBrace:Token;
}

typedef ImportDecl = {
    var importKeyword:Token;
    var identifier:Token;
    var semicolon:Token;
}
