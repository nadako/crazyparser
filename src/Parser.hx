class Parser {
    var scanner:Scanner;
    var currentToken:Token;

    public function new(text) {
        scanner = new Scanner(text);
    }

    public function nextToken():Token {
        return currentToken = scanner.scan();
    }

    public function expect(f:Token->Bool):Token {
        var token = currentToken;
        if (!f(token))
            throw 'Unexpected $token';
        nextToken();
        return token;
    }

    public function parse():Node {
        nextToken();

        var keywordToken = expect(function(t) return t.kind.match(TkKeyword(KwClass)));
        var nameToken = expect(function(t) return t.kind.match(TkIdent(_)));
        var openBraceToken = expect(function(t) return t.kind.match(TkBraceOpen));
        var closeBraceToken = expect(function(t) return t.kind.match(TkBraceClose));
        var node = new Node();
        node.kind = NClassDecl({
            classKeyword: keywordToken,
            name: nameToken,
            openBrace: openBraceToken,
            closeBrace: closeBraceToken,
        });
        node.pos = new Position(keywordToken.pos.min, closeBraceToken.pos.max);
        return node;
    }
}
