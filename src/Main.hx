class Main {
    static function main() {
        haxe.Log.trace = haxe.Log.trace;
        var filename = "Test.hx";
        var input = sys.io.File.getContent(filename);
        var scanner = new Scanner(input);
        var tok;
        do {
            tok = scanner.scan();
            trace('${tok.kind} ${tok.pos}: `${input.substring(tok.pos.start, tok.pos.end)}`');
            if (tok.leadTrivia != null) {
                for (tr in tok.leadTrivia)
                    trace(' lead ${tr.kind} ${tr.pos}: ${input.substring(tr.pos.start, tr.pos.end)}');
            }
            if (tok.trailTrivia != null) {
                for (tr in tok.trailTrivia)
                    trace(' trail ${tr.kind} ${tr.pos}: ${input.substring(tr.pos.start, tr.pos.end)}');
            }
        } while (tok.kind != TkEof);
    }
}

