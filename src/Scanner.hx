using StringTools;

class Scanner {
    var text:String;
    var pos:Int;
    var end:Int;
    var tokenStart:Int;
    var trivia:Array<Trivia>;

    public function new(input) {
        text = input;
        pos = 0;
        end = input.length;
    }

    public function scan():Token {
        while (true) {
            tokenStart = pos;
            if (pos >= end)
                return mk(TkEof);

            var ch = text.fastCodeAt(pos);
            switch (ch) {
                case " ".code | "\t".code:
                    if (trivia == null) trivia = [];
                    trivia.push(scanWhitespace());
                    continue;

                case "\r".code | "\n".code:
                    if (trivia == null) trivia = [];
                    trivia.push(scanEol(ch));
                    continue;

                case "=".code:
                    pos++;
                    if (pos < end) {
                        switch (text.fastCodeAt(pos)) {
                            case "=".code:
                                pos++;
                                return mk(TkEqualsEquals);
                            default:
                        }
                    }
                    return mk(TkEquals);

                case "+".code:
                    pos++;
                    if (pos < end) {
                        switch (text.fastCodeAt(pos)) {
                            case "=".code:
                                pos++;
                                return mk(TkPlusEquals);
                            case "+".code:
                                pos++;
                                return mk(TkPlusPlus);
                            default:
                        }
                    }
                    return mk(TkPlus);

                case "-".code:
                    pos++;
                    if (pos < end) {
                        switch (text.fastCodeAt(pos)) {
                            case "=".code:
                                pos++;
                                return mk(TkMinusEquals);
                            case "-".code:
                                pos++;
                                return mk(TkMinusMinus);
                            default:
                        }
                    }
                    return mk(TkMinus);

                case "*".code:
                    pos++;
                    if (pos < end) {
                        switch (text.fastCodeAt(pos)) {
                            case "=".code:
                                pos++;
                                return mk(TkAsteriskEquals);
                            default:
                        }
                    }
                    return mk(TkAsterisk);

                case "/".code:
                    pos++;
                    if (pos < end) {
                        switch (text.fastCodeAt(pos)) {
                            case "/".code:
                                if (trivia == null) trivia = [];
                                trivia.push(scanLineComment());
                                continue;
                            case "*".code:
                                if (trivia == null) trivia = [];
                                trivia.push(scanBlockComment());
                                continue;
                            case "=".code:
                                pos++;
                                return mk(TkSlashEquals);
                            default:
                        }
                    }
                    return mk(TkSlash);

                case "{".code:
                    pos++;
                    return mk(TkBraceOpen);

                case "}".code:
                    pos++;
                    return mk(TkBraceClose);

                case "[".code:
                    pos++;
                    return mk(TkBracketOpen);

                case "]".code:
                    pos++;
                    return mk(TkBracketClose);

                case "(".code:
                    pos++;
                    return mk(TkParenOpen);

                case ")".code:
                    pos++;
                    return mk(TkParenClose);

                case "<".code:
                    pos++;
                    return mk(TkLt);

                case ">".code:
                    pos++;
                    return mk(TkGt);

                case ".".code:
                    pos++;
                    return mk(TkDot);

                case ",".code:
                    pos++;
                    return mk(TkComma);

                case ":".code:
                    pos++;
                    return mk(TkColon);

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
                    return mk(TkIdent(text.substring(tokenStart, pos)));

                default:
                    addError('Unknown token: ${text.charAt(pos)}');
                    pos++;
                    return mk(TkUnknown);
            }
        }
    }

    public dynamic function handleError(text:String, pos:Position) {
        trace('$text $pos');
    }

    inline function addError(text:String) {
        handleError(text, new Position(tokenStart, pos));
    }

    function scanLineComment() {
        pos++;
        while (pos < end) {
            if (text.fastCodeAt(pos) == "\r".code || text.fastCodeAt(pos) == "\n".code)
                break;
            pos++;
        }
        return mkTrivia(TrLineComment);
    }

    function scanBlockComment() {
        pos++;
        var terminated = false;
        while (pos < end) {
            if (text.fastCodeAt(pos) == "*".code && pos + 1 < end && text.fastCodeAt(pos + 1) == "/".code) {
                pos += 2;
                terminated = true;
                break;
            }
            pos++;
        }
        if (!terminated)
            addError("Unterminated block comment");
        return mkTrivia(TrBlockComment);
    }

    function scanWhitespace() {
        pos++;
        while (pos < end) {
            var ch = text.fastCodeAt(pos);
            if (ch != " ".code && ch != "\t".code)
                break;
            pos++;
        }
        return mkTrivia(TrWhitespace);
    }

    function scanEol(ch:Int) {
        pos++;
        if (ch == "\r".code && pos < end && text.fastCodeAt(pos) == "\n".code)
            pos++; // treat \r\n as single TrEol trivia
        return mkTrivia(TrEol);
    }

    function scanTrailTrivia():Array<Trivia> {
        var result = null;
        while (true) {
            tokenStart = pos;
            if (pos >= end)
                break;

            var ch = text.fastCodeAt(pos);
            switch (ch) {
                case " ".code | "\t".code:
                    if (result == null) result = [];
                    result.push(scanWhitespace());
                    continue;

                case "\r".code | "\n".code:
                    if (result == null) result = [];
                    result.push(scanEol(ch));
                    break;

                case "/".code:
                    if (pos + 1 < end) {
                        switch (text.fastCodeAt(pos + 1)) {
                            case "/".code:
                                pos++;
                                if (result == null) result = [];
                                result.push(scanLineComment());
                                continue;
                            case "*".code:
                                pos++;
                                if (result == null) result = [];
                                result.push(scanBlockComment());
                                continue;
                            default:
                        }
                    }
                    break;

                default:
                    break;
            }
        }
        return result;
    }

    inline function isDigit(ch) {
        return ch >= "0".code && ch <= "9".code;
    }

    inline function isIdentStart(ch) {
        return ch == "_".code || (ch >= "a".code && ch <= "z".code) || (ch >= "A".code && ch <= "Z".code);
    }

    inline function isIdentPart(ch) {
        return isDigit(ch) || isIdentStart(ch);
    }

    function mk(kind) {
        var token = new Token(new Position(tokenStart, pos), kind);
        token.leadTrivia = trivia;
        token.trailTrivia = scanTrailTrivia();
        trivia = null;
        return token;
    }

    inline function mkTrivia(kind) {
        return new Trivia(new Position(tokenStart, pos), kind);
    }
}
