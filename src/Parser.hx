import Token;

class Parser {
    var scanner:Scanner;
    var currentToken:Token;

    public function new(text) {
        scanner = new Scanner(text);
    }

    function nextToken():Token {
        return currentToken = scanner.scan();
    }

    function expect(f:Token->Bool):Token {
        var token = currentToken;
        if (!f(token))
            throw new UnexpectedToken(token);
        nextToken();
        return token;
    }

    function expectToken(kind:TokenKind):Token {
        return expect(function(t) return t.kind == kind);
    }

    function expectKeyword(kw:Keyword):Token {
        return expect(function(t) return switch (t.kind) {
            case TkKeyword(foundKw) if (foundKw == kw): true;
            default: false;
        });
    }

    function parseList<T:Node>(parseElement:Void->T):Array<T> {
        var result = [];
        while (currentToken.kind != TkEof)  {
            try {
                result.push(parseElement());
            } catch (e:UnexpectedToken) {
                trace(e.token);
                break;
            }
        }
        return result;
    }

    public function parse():Array<Node> {
        nextToken();
        return parseList(parseModuleDecl);
    }

    function parseClass():Node {
        var keywordToken = expectKeyword(KwClass);
        var nameToken = expect(function(t) return t.kind.match(TkIdent(_)));
        var openBraceToken = expectToken(TkBraceOpen);
        var closeBraceToken = expectToken(TkBraceClose);
        var node = new Node(NClassDecl({
            classKeyword: keywordToken,
            name: nameToken,
            openBrace: openBraceToken,
            closeBrace: closeBraceToken,
        }));
        node.pos = new Position(keywordToken.pos.min, closeBraceToken.pos.max);
        return node;
    }

    function parseImport():Node {
        var importToken = expectKeyword(KwImport);
        var nameToken = expect(function(t) return t.kind.match(TkIdent(_)));
        var semicolonToken = expectToken(TkSemicolon);
        var node = new Node(NImportDecl({
            importKeyword: importToken,
            identifier: nameToken,
            semicolon: semicolonToken,
        }));
        node.pos = new Position(importToken.pos.min, semicolonToken.pos.max);
        return node;
    }

    function parseModuleDecl():Node {
        return switch (currentToken.kind) {
            case TkKeyword(KwImport):
                parseImport();
            case TkKeyword(KwClass):
                parseClass();
            default:
                throw new UnexpectedToken(currentToken);
        }
    }
}

class UnexpectedToken {
    public var token:Token;
    public function new(token) {
        this.token = token;
    }
}
