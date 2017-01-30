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
    TkParenOpen;
    TkParenClose;
    TkBraceOpen;
    TkBraceClose;
    TkColon;
    TkSemicolon;
    TkDot;
    TkComma;
    TkLt;
    TkGt;
    TkEquals;
    TkPlus;
    TkMinus;
    TkAsterisk;
    TkSlash;
    TkQuestion;
    TkInteger(s:String);
    TkString(s:String);
}

enum Keyword {
    KwClass;
    KwInterface;
    KwAbstract;
    KwTypedef;
    KwFunction;
    KwVar;
    KwImport;
    KwUsing;
}
