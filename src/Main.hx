import Sys.println;
using StringTools;

class Position {
    public var min:Int;
    public var max:Int;

    public function new(min, max) {
        this.min = min;
        this.max = max;
    }

    public function toString() {
        return '[$min..$max)';
    }
}

class Token {
    public var kind:TokenKind;
    public var pos:Position;
    public var leadTrivia:Array<Trivia>;
    public var trailTrivia:Array<Trivia>;

    public function new(kind, pos) {
        this.kind = kind;
        this.pos = pos;
    }

    public function toString() {
        return '$kind $pos';
    }
}

enum TokenKind {
    TkEof;
    TkUnknown;
    TkKeyword(keyword:Keyword);
    TkIdent(ident:String);
    TkBraceOpen;
    TkBraceClose;
}

enum Keyword {
    KwClass;
}

class Trivia {
    public var kind:TriviaKind;
    public var text:String;
    public var pos:Position;

    public function new(kind, text, pos) {
        this.kind = kind;
        this.text = text;
        this.pos = pos;
    }

    public function toString() {
        return '$kind $pos';
    }
}

enum TriviaKind {
    TrWhitespace;
    TrEndOfLine;
    TrSingleLineComment;
    TrMultiLineComment;
}

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
}

typedef ClassDecl = {
    var classKeyword:Token;
    var name:Token;
    var openBrace:Token;
    var closeBrace:Token;
}

class Scanner {
    var text:String;
    var pos:Int;
    var end:Int;
    var tokenStartPos:Int;
    var trivia:Array<Trivia>;

    public function new(text) {
        this.text = text;
        pos = 0;
        end = text.length;
    }

    public function scan():Token {
        while (true) {
            tokenStartPos = pos;

            if (pos >= end)
                return mk(TkEof);

            var ch = text.fastCodeAt(pos);
            switch (ch) {
                case " ".code | "\t".code:
                    pos++;
                    while (pos < end) {
                        var ch = text.fastCodeAt(pos);
                        if (!isWhiteSpace(ch))
                            break;
                        pos++;
                    }
                    if (trivia == null) trivia = [];
                    trivia.push(mkTrivia(TrWhitespace));
                    continue;

                case "\r".code | "\n".code:
                    pos++;
                    if (ch == "\r".code && pos < end && text.fastCodeAt(pos) == "\n".code)
                        pos++;

                    if (trivia == null) trivia = [];
                    trivia.push(mkTrivia(TrEndOfLine));
                    continue;

                case "/".code:
                    pos++;
                    if (pos < end && text.fastCodeAt(pos) == "*".code) { // multiline comment
                        pos++;
                        while (pos < end) {
                            if (text.fastCodeAt(pos) == "*".code && pos + 1 < end && text.fastCodeAt(pos + 1) == "/".code) {
                                pos += 2;
                                break;
                            }
                            pos++;
                        }
                        if (trivia == null) trivia = [];
                        trivia.push(mkTrivia(TrMultiLineComment));
                        continue;
                    }
                    return mk(TkUnknown); // really TkSlash

                case "{".code:
                    pos++;
                    return mk(TkBraceOpen);

                case "}".code:
                    pos++;
                    return mk(TkBraceClose);

                case _ if (isIdentStart(ch)):
                    pos++;
                    while (pos < end) {
                        var ch = text.fastCodeAt(pos);
                        if (!isIdentPart(ch))
                            break;
                        pos++;
                    }
                    return mkIdentOrKeyword();

                default:
                    pos++;
                    return mk(TkUnknown);
            }
        }
    }

    function consumeTrailTrivia():Array<Trivia> {
        var result = null;
        while (true) {
            tokenStartPos = pos;
            if (pos >= end)
                break;

            var ch = text.fastCodeAt(pos);
            switch (ch) {
                case " ".code | "\t".code:
                    pos++;
                    while (pos < end) {
                        var ch = text.fastCodeAt(pos);
                        if (!isWhiteSpace(ch))
                            break;
                        pos++;
                    }
                    if (result == null) result = [];
                    result.push(mkTrivia(TrWhitespace));
                    continue;

                case "\r".code | "\n".code:
                    pos++;
                    if (ch == "\r".code && pos < end && text.fastCodeAt(pos) == "\n".code)
                        pos++;

                    if (result == null) result = [];
                    result.push(mkTrivia(TrEndOfLine));
                    break;

                case "/".code:
                    if (pos + 1 < end && text.fastCodeAt(pos + 1) == "*".code) { // multiline comment
                        pos += 2;
                        while (pos < end) {
                            if (text.fastCodeAt(pos) == "*".code && pos + 1 < end && text.fastCodeAt(pos + 1) == "/".code) {
                                pos += 2;
                                break;
                            }
                            pos++;
                        }
                        if (result == null) result = [];
                        result.push(mkTrivia(TrMultiLineComment));
                        continue;
                    }
                    break;

                default:
                    break;
            }
        }
        return result;
    }

    inline function isWhiteSpace(ch)
        return ch == " ".code || ch == "\t".code;

    inline function isNumber(ch)
        return ch >= "0".code && ch <= "9".code;

    inline function isIdentStart(ch)
        return ch == "_".code || (ch >= "a".code && ch <= "z".code) || (ch >= "A".code && ch <= "Z".code);

    inline function isIdentPart(ch)
        return isNumber(ch) || isIdentStart(ch);

    function mkIdentOrKeyword() {
        var ident = tokenText();
        return mk(switch (ident) {
            case "class": TkKeyword(KwClass);
            default: TkIdent(ident);
        });
    }

    inline function tokenText()
        return text.substring(tokenStartPos, pos);

    inline function mk(kind) {
        var token = new Token(kind, new Position(tokenStartPos, pos));
        token.leadTrivia = trivia;
        token.trailTrivia = consumeTrailTrivia();
        trivia = null;
        return token;
    }

    inline function mkTrivia(kind) {
        return new Trivia(kind, tokenText(), new Position(tokenStartPos, pos));
    }
}

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

        // println(root);

        // var scanner = new Scanner(src);


        // var token;
        // do {
        //     token = scanner.scan();
        // } while (token.kind != TkEof);
    }
}
