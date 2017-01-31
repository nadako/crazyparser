package haxeparser;

import haxeparser.Data;
import hxparse.Lexer;

enum LexerErrorMsg {
    UnterminatedString;
    UnterminatedRegExp;
    UnclosedComment;
    UnterminatedEscapeSequence;
    InvalidEscapeSequence(c:String);
    UnknownEscapeSequence(c:String);
    UnclosedCode;
}

class LexerError {
    public var msg:LexerErrorMsg;
    public var pos:Position;
    public function new(msg, pos) {
        this.msg = msg;
        this.pos = pos;
    }
}

class HaxeLexer extends Lexer implements hxparse.RuleBuilder {
    static var buf = new StringBuf();
    static var integer = "([1-9][0-9]*)|0";

    // @:rule wraps the expression to the right of => with function(lexer) return
    public static var tok = @:rule [
        integer + "[eE][\\+\\-]?[0-9]+" => mk(lexer,TkConst(CFloat(lexer.current))),
        integer + "\\.[0-9]*[eE][\\+\\-]?[0-9]+" => mk(lexer,TkConst(CFloat(lexer.current))),
        "'" => {
            buf = new StringBuf();
            var pmin = lexer.curPos();
            var pmax = try lexer.token(string2) catch (e:haxe.io.Eof) throw new LexerError(UnterminatedString, mkPos(pmin));
            var token = mk(lexer, TkConst(CString(unescape(buf.toString(), mkPos(pmin)))));
            token.pos.min = pmin.pmin; token;
        },
        "$[_a-zA-Z0-9]*" => mk(lexer, TkDollar(lexer.current.substr(1))),
    ];


    public static var string2 = @:rule [
        "\\\\\\\\" => {
            buf.add("\\\\");
            lexer.token(string2);
        },
        "\\\\" => {
            buf.add("\\");
            lexer.token(string2);
        },
        '\\\\\'' => {
            buf.add("'");
            lexer.token(string2);
        },
        "'" => lexer.curPos().pmax,
        "($$)|(\\$)|$" => {
            buf.add("$");
            lexer.token(string2);
        },
        "${" => {
            var pmin = lexer.curPos();
            buf.add(lexer.current);
            try lexer.token(codeString) catch(e:haxe.io.Eof) throw new LexerError(UnclosedCode, mkPos(pmin));
            lexer.token(string2);
        },
        "[^$\\\\']+" => {
            buf.add(lexer.current);
            lexer.token(string2);
        }
    ];

    public static var codeString = @:rule [
        "{|/" => {
            buf.add(lexer.current);
            lexer.token(codeString);
        },
        "}" => {
            buf.add(lexer.current);
        },
        '"' => {
            buf.addChar('"'.code);
            var pmin = lexer.curPos();
            try lexer.token(string) catch (e:haxe.io.Eof) throw new LexerError(UnterminatedString, mkPos(pmin));
            buf.addChar('"'.code);
            lexer.token(codeString);
        },
        "'" => {
            buf.addChar("'".code);
            var pmin = lexer.curPos();
            try lexer.token(string2) catch (e:haxe.io.Eof) throw new LexerError(UnterminatedString, mkPos(pmin));
            buf.addChar("'".code);
            lexer.token(codeString);
        },
        '/\\*' => {
            var pmin = lexer.curPos();
            try lexer.token(comment) catch (e:haxe.io.Eof) throw new LexerError(UnclosedComment, mkPos(pmin));
            lexer.token(codeString);
        },
        "//[^\n\r]*" => {
            buf.add(lexer.current);
            lexer.token(codeString);
        },
        "[^/\"'{}\n\r]+" => {
            buf.add(lexer.current);
            lexer.token(codeString);
        }
    ];

    public static var comment = @:rule [
        "*/" => lexer.curPos().pmax,
        "*" => {
            buf.add("*");
            lexer.token(comment);
        },
        "[^\\*]+" => {
            buf.add(lexer.current);
            lexer.token(comment);
        }
    ];

    public static var regexp = @:rule [
        "\\\\/" => {
            buf.add("/");
            lexer.token(regexp);
        },
        "\\\\r" => {
            buf.add("\r");
            lexer.token(regexp);
        },
        "\\\\n" => {
            buf.add("\n");
            lexer.token(regexp);
        },
        "\\\\t" => {
            buf.add("\t");
            lexer.token(regexp);
        },
        "\\\\[\\\\$\\.*+\\^|{}\\[\\]()?\\-0-9]" => {
            buf.add(lexer.current);
            lexer.token(regexp);
        },
        "\\\\[wWbBsSdDx]" => {
            buf.add(lexer.current);
            lexer.token(regexp);
        },
        "/" => {
            lexer.token(regexp_options);
        },
        "[^\\\\/\r\n]+" => {
            buf.add(lexer.current);
            lexer.token(regexp);
        }
    ];

    public static var regexp_options = @:rule [
        "[gimsu]*" => {
            { pmax:lexer.curPos().pmax, opt:lexer.current };
        }
    ];

    static inline function unescapePos(pos:Position, index:Int, length:Int) {
        return new Position(pos.file, pos.min + index, pos.min + index + length);
    }

    static function unescape(s:String, pos:Position) {
        var b = new StringBuf();
        var i = 0;
        var esc = false;
        while (true) {
            if (s.length == i) {
                break;
            }
            var c = s.charCodeAt(i);
            if (esc) {
                var iNext = i + 1;
                switch (c) {
                    case _ >= '0'.code && _ <= '3'.code => true:
                        iNext += 2;
                    case 'x'.code:
                        var chars = s.substr(i + 1, 2);
                        if (!(~/^[0-9a-fA-F]{2}$/.match(chars))) throw new LexerError(InvalidEscapeSequence("\\x"+chars), unescapePos(pos, i, 1 + 2));
                        var c = Std.parseInt("0x" + chars);
                        b.addChar(c);
                        iNext += 2;
                    case 'u'.code:
                        var c:Int;
                        if (s.charAt(i + 1) == "{") {
                            var endIndex = s.indexOf("}", i + 3);
                            if (endIndex == -1) throw new LexerError(UnterminatedEscapeSequence, unescapePos(pos, i, 2));
                            var l = endIndex - (i + 2);
                            var chars = s.substr(i + 2, l);
                            if (!(~/^[0-9a-fA-F]+$/.match(chars))) throw new LexerError(InvalidEscapeSequence("\\u{"+chars+"}"), unescapePos(pos, i, 1 + 2 + l));
                            c = Std.parseInt("0x" + chars);
                            if (c > 0x10FFFF) throw new LexerError(InvalidEscapeSequence("\\u{"+chars+"}"), unescapePos(pos, i, 1 + 2 + l));
                            iNext += 2 + l;
                        } else {
                            var chars = s.substr(i + 1, 4);
                            if (!(~/^[0-9a-fA-F]{4}$/.match(chars))) throw new LexerError(InvalidEscapeSequence("\\u"+chars), unescapePos(pos, i, 1 + 4));
                            c = Std.parseInt("0x" + chars);
                            iNext += 4;
                        }
                        b.addChar(c);
                    case c:
                        throw new LexerError(UnknownEscapeSequence("\\"+String.fromCharCode(c)), unescapePos(pos, i, 1));
                }
                esc = false;
                i = iNext;
            } else switch (c) {
                case '\\'.code:
                    ++i;
                    esc = true;
                case _:
                    b.addChar(c);
                    ++i;
            }

        }
        return b.toString();
    }
}
