using StringTools;

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

                case ".".code:
                    pos++;
                    return mk(TkDot);

                case ";".code:
                    pos++;
                    return mk(TkSemicolon);

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
            case "interface": TkKeyword(KwInterface);
            case "abstract": TkKeyword(KwAbstract);
            case "typedef": TkKeyword(KwTypedef);
            case "import": TkKeyword(KwImport);
            case "using": TkKeyword(KwUsing);
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
