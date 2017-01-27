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
