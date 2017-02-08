class Trivia {
    public var pos:Position;
    public var kind:TriviaKind;

    public inline function new(pos, kind) {
        this.pos = pos;
        this.kind = kind;
    }

    public inline function toString() {
        return '$kind $pos';
    }
}

enum TriviaKind {
    TrWhitespace;
    TrEol;
    TrLineComment;
    TrBlockComment;
    TrIfDirective;
    TrDisabledText;
    TrElseDirective;
    TrElseIfDirective;
    TrEndDirective;
    TrErrorDirective;
    TrLineDirective;
}
