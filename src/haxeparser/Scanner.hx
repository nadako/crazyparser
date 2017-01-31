package haxeparser;

using StringTools;

import haxeparser.Data;

class Scanner {
    var input:String;
    var file:String;
    var pos:Int;
    var end:Int;
    var tokenStart:Int;

    public function new(input, file) {
        this.input = input;
        this.file = file;
        this.pos = 0;
        this.end = input.length;
    }

    public function token():Token {
        while (true) {
            tokenStart = pos;
            if (pos >= end)
                return mk(TkEof);

            var ch = input.fastCodeAt(pos);
            switch (ch) {
                case " ".code | "\t".code:
                    pos++;
                    while (pos < end) {
                        var ch = input.fastCodeAt(pos);
                        if (!isWhiteSpace(ch))
                            break;
                        pos++;
                    }
                    // TODO: push trivia
                    continue;

                case "\r".code | "\n".code:
                    pos++;
                    if (ch == "\r".code && pos < end && input.fastCodeAt(pos) == "\n".code) // single newline trivia for crlf
                        pos++;
                    // TODO: push trivia
                    continue;

                case ":".code:
                    pos++;
                    return mk(TkColon);

                case ";".code:
                    pos++;
                    return mk(TkSemicolon);

                case ".".code:
                    pos++;
                    if (pos < end) {
                        switch (input.fastCodeAt(pos)) {
                            case ".".code if (pos + 1 < end && input.fastCodeAt(pos + 1) == ".".code):
                                pos += 2;
                                return mk(TkBinop(OpInterval));

                            case ch if (isNumber(ch)):
                                pos++;
                                while (pos < end) {
                                    var ch = input.fastCodeAt(pos);
                                    if (!isNumber(ch))
                                        break;
                                    pos++;
                                }
                                return mk(TkConst(CFloat(input.substring(tokenStart, pos))));

                            default:
                        }
                    }
                    return mk(TkDot);

                case ",".code:
                    pos++;
                    return mk(TkComma);

                case "(".code:
                    pos++;
                    return mk(TkParenOpen);

                case ")".code:
                    pos++;
                    return mk(TkParenClose);

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

                case "<".code:
                    pos++;
                    if (pos < end) {
                        switch (input.fastCodeAt(pos)) {
                            case "<".code:
                                pos++;
                                if (pos < end && input.fastCodeAt(pos) == "=".code) {
                                    pos++;
                                    return mk(TkBinop(OpAssignOp(OpShl)));
                                }
                                return mk(TkBinop(OpShl));
                            case "=".code:
                                pos++;
                                return mk(TkBinop(OpLte));
                            default:
                        }
                    }
                    return mk(TkBinop(OpLt));

                case ">".code:
                    pos++;
                    return mk(TkBinop(OpGt));

                case "@".code:
                    pos++;
                    return mk(TkAt);

                case "?".code:
                    pos++;
                    return mk(TkQuestion);

                case "~".code:
                    pos++;
                    if (pos < end && input.fastCodeAt(pos) == "/".code) { // EREG
                        pos++;
                        var r = scanRegexp();
                        return mk(TkConst(CRegexp(r.pattern, r.options)));
                    }
                    return mk(TkTilde);

                case "!".code:
                    pos++;
                    if (pos < end && input.fastCodeAt(pos) == "=".code) {
                        pos++;
                        return mk(TkBinop(OpNotEq));
                    }
                    return mk(TkExclamation);

                case "%".code:
                    pos++;
                    if (pos < end && input.fastCodeAt(pos) == "=".code) {
                        pos++;
                        return mk(TkBinop(OpAssignOp(OpMod)));
                    }
                    return mk(TkBinop(OpMod));

                case "&".code:
                    pos++;
                    if (pos < end) {
                        switch (input.fastCodeAt(pos)) {
                            case "&".code:
                                pos++;
                                return mk(TkBinop(OpBoolAnd));
                            case "=".code:
                                pos++;
                                return mk(TkBinop(OpAssignOp(OpAnd)));
                            default:
                        }
                    }
                    return mk(TkBinop(OpAnd));

                case "|".code:
                    pos++;
                    if (pos < end) {
                        switch (input.fastCodeAt(pos)) {
                            case "|".code:
                                pos++;
                                return mk(TkBinop(OpBoolOr));
                            case "=".code:
                                pos++;
                                return mk(TkBinop(OpAssignOp(OpOr)));
                            default:
                        }
                    }
                    return mk(TkBinop(OpOr));

                case "^".code:
                    pos++;
                    if (pos < end && input.fastCodeAt(pos) == "=".code) {
                        pos++;
                        return mk(TkBinop(OpAssignOp(OpXor)));
                    }
                    return mk(TkBinop(OpXor));

                case "+".code:
                    pos++;
                    if (pos < end) {
                        switch (input.fastCodeAt(pos)) {
                            case "+".code:
                                pos++;
                                return mk(TkPlusPlus);
                            case "=".code:
                                pos++;
                                return mk(TkBinop(OpAssignOp(OpAdd)));
                            default:
                        }
                    }
                    return mk(TkBinop(OpAdd));

                case "*".code:
                    pos++;
                    if (pos < end && input.fastCodeAt(pos) == "=".code) {
                        pos++;
                        return mk(TkBinop(OpAssignOp(OpMult)));
                    }
                    return mk(TkBinop(OpMult));

                case "/".code:
                    pos++;
                    if (pos < end) {
                        switch (input.fastCodeAt(pos)) {
                            case "/".code: // single-line comment
                                pos++;
                                while (pos < end) {
                                    if (input.fastCodeAt(pos) == "\r".code || input.fastCodeAt(pos) == "\n".code) {
                                        break;
                                    }
                                    pos++;
                                }
                                // TODO: push trivia
                                continue;

                            case "*".code: // multi-line comment
                                pos++;
                                while (pos < end) {
                                    if (input.fastCodeAt(pos) == "*".code && pos + 1 < end && input.fastCodeAt(pos + 1) == "/".code) {
                                        pos += 2;
                                        break;
                                    }
                                    pos++;
                                }
                                // TODO: push trivia
                                continue;

                            case "=".code:
                                pos++;
                                return mk(TkBinop(OpAssignOp(OpDiv)));

                            default:
                        }
                    }
                    return mk(TkBinop(OpDiv));

                case "=".code:
                    pos++;
                    if (pos < end) {
                        switch (input.fastCodeAt(pos)) {
                            case ">".code:
                                pos++;
                                return mk(TkBinop(OpArrow));
                            case "=".code:
                                pos++;
                                return mk(TkBinop(OpEq));
                            default:
                        }
                    }
                    return mk(TkBinop(OpAssign));

                case "-".code:
                    pos++;
                    if (pos < end) {
                        switch (input.fastCodeAt(pos)) {
                            case "-".code:
                                pos++;
                                return mk(TkMinusMinus);
                            case "=".code:
                                pos++;
                                return mk(TkBinop(OpAssignOp(OpSub)));
                            case ">".code:
                                pos++;
                                return mk(TkArrow);
                            default:
                        }
                    }
                    return mk(TkBinop(OpSub));

                case "\"".code:
                    pos++;
                    return mk(TkConst(CString(scanString())));

                case "0".code:
                    pos++;
                    if (pos < end) {
                        switch (input.fastCodeAt(pos)) {
                            case "x".code: // hexadecimal
                                pos++;
                                var hasHex = false;
                                while (pos < end) {
                                    var ch = input.fastCodeAt(pos);
                                    if (!isHex(ch))
                                        break;
                                    hasHex = true;
                                    pos++;
                                }

                                var hexString = if (!hasHex) {
                                    // TODO: report diagnostic here
                                    trace("UNTERMINATED HEX SEQUENCE");
                                    "0x0";
                                } else {
                                    input.substring(tokenStart, pos);
                                }
                                return mk(TkConst(CInt(hexString)));

                            case ".".code: // 0.
                                // handle special case 0... - return CInt(0) here and parse interval token at next iteration
                                if (pos + 2 < end && input.fastCodeAt(pos + 1) == ".".code && input.fastCodeAt(pos + 2) == ".".code) {
                                    return mk(TkConst(CInt("0")));
                                }

                                pos++;
                                while (pos < end) {
                                    var ch = input.fastCodeAt(pos);
                                    if (!isNumber(ch))
                                        break;
                                    pos++;
                                }
                                return mk(TkConst(CFloat(input.substring(tokenStart, pos))));

                            default:
                        }
                    }
                    return mk(TkConst(CInt("0")));

                case "1".code | "2".code | "3".code | "4".code | "5".code | "6".code | "7".code | "8".code | "9".code:
                    pos++;
                    while (pos < end) {
                        var ch = input.fastCodeAt(pos);
                        if (!isNumber(ch))
                            break;
                        pos++;
                    }
                    return mk(TkConst(CInt(input.substring(tokenStart, pos))));

                case _ if (isIdentStart(ch)):
                    pos++;
                    while (pos < end) {
                        var ch = input.fastCodeAt(pos);
                        if (!isIdentPart(ch))
                            break;
                        pos++;
                    }
                    return mkIdentOrKeyword();

                default:
                    pos++;
                    // TODO: report diagnostic
                    trace('Unexpected character: ${String.fromCharCode(ch)}');
                    return mk(TkInvalid);
            }
        }
    }

    public inline function curPos():Position {
        return new Position(file, tokenStart, pos);
    }

    function mkIdentOrKeyword() {
        var ident = tokenText();
        return mk(switch (ident) {
            case "function": TkKeyword(KwFunction);
            case "class": TkKeyword(KwClass);
            case "var": TkKeyword(KwVar);
            case "if": TkKeyword(KwIf);
            case "else": TkKeyword(KwElse);
            case "while": TkKeyword(KwWhile);
            case "do": TkKeyword(KwDo);
            case "for": TkKeyword(KwFor);
            case "break": TkKeyword(KwBreak);
            case "continue": TkKeyword(KwContinue);
            case "return": TkKeyword(KwReturn);
            case "extends": TkKeyword(KwExtends);
            case "implements": TkKeyword(KwImplements);
            case "import": TkKeyword(KwImport);
            case "switch": TkKeyword(KwSwitch);
            case "case": TkKeyword(KwCase);
            case "default": TkKeyword(KwDefault);
            case "static": TkKeyword(KwStatic);
            case "public": TkKeyword(KwPublic);
            case "private": TkKeyword(KwPrivate);
            case "try": TkKeyword(KwTry);
            case "catch": TkKeyword(KwCatch);
            case "new": TkKeyword(KwNew);
            case "this": TkKeyword(KwThis);
            case "throw": TkKeyword(KwThrow);
            case "extern": TkKeyword(KwExtern);
            case "enum": TkKeyword(KwEnum);
            case "in": TkKeyword(KwIn);
            case "interface": TkKeyword(KwInterface);
            case "untyped": TkKeyword(KwUntyped);
            case "cast": TkKeyword(KwCast);
            case "override": TkKeyword(KwOverride);
            case "typedef": TkKeyword(KwTypedef);
            case "dynamic": TkKeyword(KwDynamic);
            case "package": TkKeyword(KwPackage);
            case "inline": TkKeyword(KwInline);
            case "using": TkKeyword(KwUsing);
            case "null": TkKeyword(KwNull);
            case "true": TkKeyword(KwTrue);
            case "false": TkKeyword(KwFalse);
            case "abstract": TkKeyword(KwAbstract);
            case "macro": TkKeyword(KwMacro);
            default: TkConst(CIdent(ident));
        });
    }

    function scanRegexp():{pattern:String, options:String} {
        var pattern = "";
        var options = "";
        var start = pos;
        while (true) {
            if (pos >= end) {
                pattern += input.substring(start, pos);
                trace("UNTERMINATED REGEXP"); // TODO: emit diagnostic here
                break;
            }

            // A HUGE TODO

            var ch = input.fastCodeAt(pos);
            if (ch == "/".code) {
                pattern += input.substring(start, pos);
                pos++;
                // TODO: scan options
                break;
            } else {
                pos++;
            }
        }
        return {pattern: pattern, options: options};
    }

    function scanString():String {
        var result = "";
        var start = pos;
        while (true) {
            if (pos >= end) {
                result += input.substring(start, pos);
                trace("UNTERMINATED STRING"); // TODO: this should emit a diagnostic and mark token as errored
                break;
            }
            var ch = input.fastCodeAt(pos);
            if (ch == "\"".code) {
                result += input.substring(start, pos);
                pos++;
                break;
            } else if (ch == "\\".code) {
                result += input.substring(start, pos);
                pos++;
                result += scanEscapeSequence();
                start = pos;
            } else {
                pos++;
            }
        }
        return result;
    }

    function scanEscapeSequence():String {
        if (pos >= end) {
            trace("UNTERMINATED ESCAPE SEQUENCE"); // TODO: this should emit a diagnostic and mark token as errored
            return "";
        }
        var ch = input.fastCodeAt(pos);
        pos++;
        return switch (ch) {
            case "t".code:
                "\t";
            case "n".code:
                "\n";
            case "r".code:
                "\r";
            case "\"".code:
                "\"";
            case "'".code:
                "'";
            case "\\".code:
                "\\";
            default:
                // TODO: other sequences
                trace("INVALID ESCAPE SEQUENCE"); // TODO: this should emit a diagnostic and mark token as errored
                "";
        }
    }

    inline function isWhiteSpace(ch)
        return ch == " ".code || ch == "\t".code;

    inline function isNumber(ch)
        return ch >= "0".code && ch <= "9".code;

    inline function isHex(ch)
        return isNumber(ch) || (ch >= "a".code && ch <= "f".code) || (ch >= "A".code && ch <= "F".code);

    inline function isIdentStart(ch)
        return ch == "_".code || (ch >= "a".code && ch <= "z".code) || (ch >= "A".code && ch <= "Z".code);

    inline function isIdentPart(ch)
        return isNumber(ch) || isIdentStart(ch);

    inline function tokenText()
        return input.substring(tokenStart, pos);

    inline function mk(kind)
        return new Token(kind, curPos());
}
