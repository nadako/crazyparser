class Token {
    public var pos:Position;
    public var kind:TokenKind;
    public var leadTrivia:Array<Trivia>;
    public var trailTrivia:Array<Trivia>;

    public inline function new(pos, kind) {
        this.pos = pos;
        this.kind = kind;
    }

    public inline function toString() {
        return '$kind $pos';
    }
}

enum TokenKind {
    TkEof;
    TkUnknown;
    TkIdent(ident:String);
    TkBraceOpen;
    TkBraceClose;
    TkParenOpen;
    TkParenClose;
    TkBracketOpen;
    TkBracketClose;
    TkLt;
    TkLtLt;
    TkLtEquals;
    TkGt;
    TkGtGt;
    TkGtEquals;
    TkColon;
    TkSemicolon;
    TkDot;
    TkComma;
    TkEquals;
    TkEqualsEquals;
    TkEqualsGt;
    TkPlus;
    TkPlusPlus;
    TkPlusEquals;
    TkMinus;
    TkMinusMinus;
    TkMinusEquals;
    TkMinusGt;
    TkAsterisk;
    TkAsteriskEquals;
    TkSlash;
    TkSlashEquals;
    TkTilde;
    TkCaret;
    TkCaretEquals;
    TkExc;
    TkExcEquals;
}
