class Main {
    static function main() {
        haxe.Log.trace = haxe.Log.trace;
        var file = "Test.hx";
        var input = sys.io.File.getContent(file);
        var parser = new haxeparser.HaxeParser(input, file);
        var result = parser.parse();
        trace('Package: ${result.pack.join(".")}');
        for (decl in result.decls) {
            trace(decl.pos);
            switch (decl.decl) {
                // case EClass(cl):
                //     trace(untyped cl.data[0].kind[2].expr.expr[2][0].expr[2].expr[3].expr.slice(2));
                case other:
                    trace(other);
            }
        }
    }
}
