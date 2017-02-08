import Trivia;
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
                    pushTrivia(scanWhitespace());
                    continue;

                case "\r".code | "\n".code:
                    pushTrivia(scanEol(ch));
                    continue;

                case "=".code:
                    pos++;
                    if (pos < end) {
                        switch (text.fastCodeAt(pos)) {
                            case "=".code:
                                pos++;
                                return mk(TkEqualsEquals);
                            case ">".code:
                                pos++;
                                return mk(TkEqualsGt);
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
                            case ">".code:
                                pos++;
                                return mk(TkMinusGt);
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
                                pushTrivia(scanLineComment());
                                continue;
                            case "*".code:
                                pushTrivia(scanBlockComment());
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
                    if (pos < end) {
                        switch (text.fastCodeAt(pos)) {
                            case "<".code:
                                pos++;
                                return mk(TkLtLt);
                            case "=".code:
                                pos++;
                                return mk(TkLtEquals);
                            default:
                        }
                    }
                    return mk(TkLt);

                case ">".code:
                    pos++;
                    if (pos < end) {
                        switch (text.fastCodeAt(pos)) {
                            case ">".code:
                                pos++;
                                if (pos < end) {
                                    switch (text.fastCodeAt(pos)) {
                                        case ">".code:
                                            pos++;
                                            if (pos < end && text.fastCodeAt(pos) == "=".code) {
                                                pos++;
                                                return mk(TkGtGtGtEquals);
                                            }
                                            return mk(TkGtGtGt);
                                        case "=".code:
                                            pos++;
                                            return mk(TkGtGtEquals);
                                        default:
                                    }
                                }
                                return mk(TkGtGt);
                            case "=".code:
                                pos++;
                                return mk(TkGtEquals);
                            default:
                        }
                    }
                    return mk(TkGt);

                case "~".code:
                    pos++;
                    return mk(TkTilde);

                case "^".code:
                    pos++;
                    if (pos < end) {
                        switch (text.fastCodeAt(pos)) {
                            case "=".code:
                                pos++;
                                return mk(TkCaretEquals);
                            default:
                        }
                    }
                    return mk(TkCaret);

                case "!".code:
                    pos++;
                    if (pos < end) {
                        switch (text.fastCodeAt(pos)) {
                            case "=".code:
                                pos++;
                                return mk(TkExcEquals);
                            default:
                        }
                    }
                    return mk(TkExc);

                case "%".code:
                    pos++;
                    if (pos < end) {
                        switch (text.fastCodeAt(pos)) {
                            case "=".code:
                                pos++;
                                return mk(TkPercentEquals);
                            default:
                        }
                    }
                    return mk(TkPercent);

                case "&".code:
                    pos++;
                    if (pos < end) {
                        switch (text.fastCodeAt(pos)) {
                            case "&".code:
                                pos++;
                                if (pos < end && text.fastCodeAt(pos) == "=".code) {
                                    pos++;
                                    return mk(TkAmpAmpEquals);
                                }
                                return mk(TkAmpAmp);
                            case "=".code:
                                pos++;
                                return mk(TkAmpEquals);
                            default:
                        }
                    }
                    return mk(TkAmp);

                case "|".code:
                    pos++;
                    if (pos < end) {
                        switch (text.fastCodeAt(pos)) {
                            case "|".code:
                                pos++;
                                if (pos < end && text.fastCodeAt(pos) == "=".code) {
                                    pos++;
                                    return mk(TkBarBarEquals);
                                }
                                return mk(TkBarBar);
                            case "=".code:
                                pos++;
                                return mk(TkBarEquals);
                            default:
                        }
                    }
                    return mk(TkBar);

                case ".".code:
                    pos++;
                    if (pos + 1 < end && text.fastCodeAt(pos) == ".".code && text.fastCodeAt(pos + 1) == ".".code) {
                        pos += 2;
                        return mk(TkDotDotDot);
                    }
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

                case "'".code | '"'.code:
                    return mk(TkString(scanString(ch)));

                case "0".code:
                    pos++;
                    return mk(TkInt("0"));

                case "1".code | "2".code | "3".code | "4".code | "5".code | "6".code | "7".code | "8".code | "9".code:
                    pos++;
                    while (pos < end) {
                        var ch = text.fastCodeAt(pos);
                        if (!isDigit(ch))
                            break;
                        pos++;
                    }
                    return mk(TkInt(text.substring(tokenStart, pos)));

                case "#".code:
                    var directive = scanDirective();
                    if (directive == null)
                        return mk(TkUnknown);
                    pushTrivia(processDirective(directive));
                    continue;

                case _ if (isIdentStart(ch)):
                    return mk(TkIdent(scanIdent()));

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

    inline function addError(text:String, ?start) {
        if (start == null) start = tokenStart;
        handleError(text, new Position(start, pos));
    }

    inline function pushTrivia(t) {
        if (trivia == null) trivia = [];
        trivia.push(t);
    }

    function scanIdent() {
        var start = pos;
        pos++;
        while (pos < end) {
            var ch = text.fastCodeAt(pos);
            if (!isIdentPart(ch))
                break;
            pos++;
        }
        return text.substring(start, pos);
    }

    function scanString(quoteChar:Int) {
        pos++;
        var result = "";
        var start = pos;
        while (true) {
            if (pos >= end) {
                addError("Unterminated string");
                result += text.substring(start, pos);
                break;
            }
            var ch = text.fastCodeAt(pos);
            if (ch == quoteChar) {
                result += text.substring(start, pos);
                pos++;
                break;
            } else if (ch == "\\".code) {
                result += text.substring(start, pos);
                result += scanEscapeSequence();
                start = pos;
            } else {
                pos++;
            }
        }
        return result;
    }

    function scanEscapeSequence() {
        pos++;
        if (pos >= end) {
            addError("Unterminated escape sequence");
            return "";
        }
        var ch = text.fastCodeAt(pos);
        pos++;
        return switch (ch) {
            case "t".code:
                "\t";
            case "n".code:
                "\n";
            case "r".code:
                "\r";
            case '"'.code:
                '\"';
            case "'".code:
                "\'";
            default:
                addError("Invalid escape sequence");
                "";
        }
    }

    function scanDirective():Null<String> {
        pos++;

        if (pos >= end) {
            addError("Unterminated directive");
            return null;
        }

        var ch = text.fastCodeAt(pos);
        if (isIdentStart(ch)) {
            return scanIdent();
        } else {
            addError("Unterminated directive");
            return null;
        }
    }

    function processDirective(id) {
        return mkTrivia(switch (id) {
            case "if":
                TrIfDirective;
            case "elseif":
                TrElseIfDirective;
            case "else":
                TrElseDirective;
            case "end":
                TrEndDirective;
            case "error":
                var msg = null;
                var errorStart = tokenStart;
                while (pos < end) {
                    var ch = text.fastCodeAt(pos);
                    switch (ch) {
                        case "\n".code | "\r".code | " ".code | "\t".code:
                            pos++;
                        case "'".code | '"'.code:
                            errorStart = pos;
                            msg = scanString(ch);
                            break;
                        default:
                            break;
                    }
                }
                addError(if (msg == null) "Not implemented" else msg, errorStart);
                TrErrorDirective(msg);
            case "line":
                TrLineDirective;
            default:
                TrUnknownDirective;
        });
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
        inline function pushTrivia(t) {
            if (result == null) result = [];
            result.push(t);
        }

        while (true) {
            tokenStart = pos;
            if (pos >= end)
                break;

            var ch = text.fastCodeAt(pos);
            switch (ch) {
                case " ".code | "\t".code:
                    pushTrivia(scanWhitespace());
                    continue;

                case "\r".code | "\n".code:
                    pushTrivia(scanEol(ch));
                    break;

                case "/".code:
                    if (pos + 1 < end) {
                        switch (text.fastCodeAt(pos + 1)) {
                            case "/".code:
                                pos++;
                                pushTrivia(scanLineComment());
                                continue;
                            case "*".code:
                                pos++;
                                pushTrivia(scanBlockComment());
                                continue;
                            default:
                        }
                    }
                    break;

                case "#".code:
                    var directive = scanDirective();
                    if (directive == null)
                        break;
                    pushTrivia(processDirective(directive));
                    continue;

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
