package haxeparser;

import haxeparser.Data;
import haxe.ds.Option;

enum ParserErrorMsg {
    MissingSemicolon;
    MissingType;
    DuplicateDefault;
    UnclosedMacro;
    Unimplemented;
    Custom(s:String);
}

class ParserError {
    public var msg: ParserErrorMsg;
    public var pos: Position;
    public function new(message:ParserErrorMsg, pos:Position) {
        this.msg = message;
        this.pos = pos;
    }
}

enum SmallType {
    SNull;
    SBool(b:Bool);
    SFloat(f:Float);
    SString(s:String);
}

class HaxeCondParser extends hxparse.Parser<Scanner, Token> implements hxparse.ParserBuilder {
    public function new(stream){
        super(stream);
    }

    public function parseMacroCond(allowOp:Bool):{tk:Option<Token>, expr:Expr}
    {
        return switch stream {
            case [{kind: TkConst(CIdent(t)), pos:p}]:
                parseMacroIdent(allowOp, t, p);
            case [{kind: TkConst(CString(s)), pos:p}]:
                {tk:None, expr:{expr:EConst(CString(s)), pos:p}};
            case [{kind: TkConst(CInt(s)), pos:p}]:
                {tk:None, expr:{expr:EConst(CInt(s)), pos:p}};
            case [{kind: TkConst(CFloat(s)), pos:p}]:
                {tk:None, expr:{expr:EConst(CFloat(s)), pos:p}};
            case [{kind: TkKeyword(k), pos:p}]:
                parseMacroIdent(allowOp, HaxeParser.keywordString(k), p);
            case [{kind: TkParenOpen, pos:p1}, o = parseMacroCond(true), {kind: TkParenClose, pos:p2}]:
                var e = {expr:EParenthesis(o.expr), pos:HaxeParser.punion(p1, p2)};
                if (allowOp) parseMacroOp(e) else { tk:None, expr:e };
            case [{kind: TkExclamation, pos:p}, o = parseMacroCond(allowOp)]:
                {tk:o.tk, expr:HaxeParser.makeUnop(OpNot, o.expr, p)};
        }
    }

    function parseMacroIdent(allowOp:Bool, t:String, p:Position):{tk:Option<Token>, expr:Expr}
    {
        var e = {expr:EConst(CIdent(t)), pos:p};
        return if (!allowOp) { tk:None, expr:e } else parseMacroOp(e);
    }

    function parseMacroOp(e:Expr):{tk:Option<Token>, expr:Expr}
    {
        return switch peek(0) {
            case {kind: TkBinop(op)}:
                junk();
                op = switch peek(0) {
                    case {kind: TkBinop(OpAssign)} if (op == OpGt):
                        junk();
                        OpGte;
                    case _: op;
                }
                var o = parseMacroCond(true);
                {tk:o.tk, expr:HaxeParser.makeBinop(op, e, o.expr)};
            case tk:
                {tk:Some(tk), expr:e};
        }
    }
}
@:enum abstract SkipState(Int){
    var Consume    = 0;       // consume current branch
    var SkipBranch = 1;       // skip until next #elsif/#else
    var SkipRest   = 2;       // skip until #end
}

class HaxeTokenSource {
    var lexer:Scanner;
    @:allow(haxeparser.HaxeParser)
    var mstack:Array<Position>;
    @:allow(haxeparser.HaxeParser)
    var skipstates:Array<SkipState>;

    var defines:Map<String, Dynamic>;

    var condParser:HaxeCondParser;

    public function new(lexer,defines){
        this.lexer = lexer;
        this.mstack = [];
        this.defines = defines;
        this.skipstates = [Consume];
        this.condParser = new HaxeCondParser(lexer);
    }

    function lexerToken() {
        var t = lexer.token();
        trace(Std.string(t.kind));
        return t;
    }

    inline function getSt() return skipstates[skipstates.length-1];
    inline function setSt(s:SkipState) skipstates[skipstates.length-1] = s;
    inline function pushSt(s:SkipState) skipstates.push(s);
    inline function popSt(){
        return if (skipstates.length > 1) skipstates.pop() else throw 'unexpected #end';
    }

    @:access(haxeparser.HaxeCondParser)
    public function token():Token{
        while(true){
            var tk    = lexerToken();
            var state = getSt();
            switch [tk.kind,state] {
                case [TkCommentLine(_) | TkComment(_) | TkSharp("line"),_]:
                case [TkSharp("error"),Consume]:
                    var nextTok = lexerToken();
                    switch nextTok.kind {
                        case TkConst(CString(str)):throw new ParserError(Custom(str), tk.pos);
                        case _:throw new ParserError(Unimplemented, tk.pos);
                    }
                case [TkSharp("if"),Consume]:
                    mstack.push(tk.pos);
                    pushSt( enterMacro() ? Consume : SkipBranch );
                case [TkSharp("if"),SkipBranch|SkipRest]:
                    deepSkip(); // alternatively use push_st(SkipRest) here
                case [TkSharp("end"),_]:
                    mstack.pop();
                    popSt();
                case [TkSharp("elseif"),Consume]:
                    setSt(SkipRest);
                case [TkSharp("elseif"),SkipBranch]:
                    setSt( enterMacro() ? Consume : SkipBranch );
                case [TkSharp("else"),SkipBranch]:
                    setSt(Consume);
                case [TkSharp("else"),Consume]:
                    setSt(SkipRest);
                case [TkSharp(_),SkipRest]:
                case [_,Consume]:
                    return tk;
                case [TkEof,_]:
                    return tk;
                case [_,_]:
            }
        }
    }

    inline function enterMacro(){
        var o = condParser.parseMacroCond(false);
        return isTrue(eval(o.expr));
    }

    function deepSkip(){
        var lvl = 1;
        while(true){
            var tk = lexerToken();
            switch tk.kind {
                case TkSharp("if"):
                    lvl += 1;
                case TkSharp("end"):
                    lvl -= 1;
                    if (lvl == 0)
                        return;
                case TkEof:
                    throw 'unclosed macro';
                case _:
            }
        }
    }

    function isTrue(a:SmallType)
    {
        return switch a {
            case SBool(false), SNull, SFloat(0.0), SString(""): false;
            case _: true;
        }
    }

    function compare(a:SmallType, b:SmallType)
    {
        return switch [a, b] {
            case [SNull, SNull]: 0;
            case [SFloat(a), SFloat(b)]: Reflect.compare(a, b);
            case [SString(a), SString(b)]: Reflect.compare(a, b);
            case [SBool(a), SBool(b)]: Reflect.compare(a, b);
            case [SString(a), SFloat(b)]: Reflect.compare(Std.parseFloat(a), b);
            case [SFloat(a), SString(b)]: Reflect.compare(a, Std.parseFloat(b));
            case _: 0;
        }
    }

    function eval(e:Expr) {
        return switch (e.expr) {
            case EConst(CIdent(s)): defines.exists(s) ? SString(s) : SNull;
            case EConst(CString(s)): SString(s);
            case EConst(CInt(f)), EConst(CFloat(f)): SFloat(Std.parseFloat(f));
            case EBinop(OpBoolAnd, e1, e2): SBool(isTrue(eval(e1)) && isTrue(eval(e2)));
            case EBinop(OpBoolOr, e1, e2): SBool(isTrue(eval(e1)) || isTrue(eval(e2)));
            case EUnop(OpNot, _, e): SBool(!isTrue(eval(e)));
            case EParenthesis(e): eval(e);
            case EBinop(op, e1, e2):
                var v1 = eval(e1);
                var v2 = eval(e2);
                var cmp = compare(v1, v2);
                var val = switch (op)
                {
                    case OpEq: cmp == 0;
                    case OpNotEq: cmp != 0;
                    case OpGt: cmp > 0;
                    case OpGte: cmp >= 0;
                    case OpLt: cmp < 0;
                    case OpLte: cmp <= 0;
                    case _: throw "Unsupported operation";
                }
                SBool(val);
            case _: throw "Invalid condition expression";
        }
    }

    public inline function curPos() {
        return lexer.curPos();
    }
}

class HaxeParser extends hxparse.Parser<HaxeTokenSource, Token> implements hxparse.ParserBuilder {

    var defines:Map<String, Dynamic>;

    var doResume = false;
    var inMacro:Bool;

    public function new(input:String, sourceName:String) {
        defines = new Map();
        defines.set("true", true);

        var lexer = new Scanner(input, sourceName);
        var ts = new HaxeTokenSource(lexer, defines);
        super(ts);

        inMacro = false;
    }

    public function define(flag:String, ?value:Dynamic)
    {
        defines.set(flag, value);
    }

    public function parse() {
        var res = parseFile();
        if (stream.mstack.length != 0) throw new ParserError(UnclosedMacro, stream.mstack[stream.mstack.length-1]);
        return res;
    }

    @:allow(haxeparser.HaxeCondParser)
    static function keywordString(k:Keyword)
    {
        return Std.string(k).substr(3).toLowerCase();
    }

    @:allow(haxeparser.HaxeCondParser)
    static function punion(p1:Position, p2:Position) {
        return new Position(p1.file, p1.min < p2.min ? p1.min : p2.min, p1.max > p2.max ? p1.max : p2.max);
    }

    static function quoteIdent(s:String) {
        // TODO
        return s;
    }

    static function isLowerIdent(s:String) {
        function loop(p) {
            var c = s.charCodeAt(p);
            return if (c >= 'a'.code && c <= 'z'.code)
                true
            else if (c == '_'.code) {
                if (p + 1 < s.length)
                    loop(p + 1);
                else
                    true;
            } else
                false;
        }
        return loop(0);
    }

    static function isPostfix(e:Expr) {
        return switch(e.expr) {
            case EConst(_) | EField(_) | EArray(_):
                true;
            case _:
                false;
        }
    }

    static function precedence(op:Binop) {
        var left = true;
        var right = false;
        return switch(op) {
            case OpMod : {p: 0, left: left};
            case OpMult | OpDiv : {p: 0, left: left};
            case OpAdd | OpSub : {p: 0, left: left};
            case OpShl | OpShr | OpUShr : {p: 0, left: left};
            case OpOr | OpAnd | OpXor : {p: 0, left: left};
            case OpEq | OpNotEq | OpGt | OpLt | OpGte | OpLte : {p: 0, left: left};
            case OpInterval : {p: 0, left: left};
            case OpBoolAnd : {p: 0, left: left};
            case OpBoolOr : {p: 0, left: left};
            case OpArrow : {p: 0, left: left};
            case OpAssign | OpAssignOp(_) : {p:10, left:right};
        }
    }

    static function isNotAssign(op:Binop) {
        return switch(op) {
            case OpAssign | OpAssignOp(_): false;
            case _: true;
        }
    }

    static function isDollarIdent(e:Expr) {
        return switch (e.expr) {
            case EConst(CIdent(n)) if (n.charCodeAt(0) == "$".code): true;
            case _: false;
        }
    }

    static function swap(op1:Binop, op2:Binop) {
        var i1 = precedence(op1);
        var i2 = precedence(op2);
        return i1.left && i1.p <= i2.p;
    }

    @:allow(haxeparser.HaxeCondParser)
    static function makeBinop(op:Binop, e:Expr, e2:Expr) {
        return switch (e2.expr) {
            case EBinop(_op,_e,_e2) if (swap(op,_op)):
                var _e = makeBinop(op,e,_e);
                {expr: EBinop(_op,_e,_e2), pos:punion(_e.pos,_e2.pos)};
            case ETernary(e1,e2,e3) if (isNotAssign(op)):
                var e = makeBinop(op,e,e1);
                {expr:ETernary(e,e2,e3), pos:punion(e.pos, e3.pos)};
            case _:
                { expr: EBinop(op,e,e2), pos:punion(e.pos, e2.pos)};
        }
    }

    @:allow(haxeparser.HaxeCondParser)
    static function makeUnop(op:Unop, e:Expr, p1:Position) {
        return switch(e.expr) {
            case EBinop(bop,e,e2):
                { expr: EBinop(bop, makeUnop(op,e,p1), e2), pos: punion(p1,e.pos)};
            case ETernary(e1,e2,e3):
                { expr: ETernary(makeUnop(op,e1,p1), e2, e3), pos:punion(p1,e.pos)};
            case _:
                { expr: EUnop(op,false,e), pos:punion(p1,e.pos)};
        }
    }

    static function makeMeta(name:String, params:Array<Expr>, e:Expr, p1:Position) {
        return switch(e.expr) {
            case EBinop(bop,e,e2):
                { expr: EBinop(bop, makeMeta(name,params,e,p1), e2), pos: punion(p1,e.pos)};
            case ETernary(e1,e2,e3):
                { expr: ETernary(makeMeta(name,params,e1,p1), e2, e3), pos:punion(p1,e.pos)};
            case _:
                { expr: EMeta({name:name, params:params, pos:p1}, e), pos: punion(p1, e.pos) };
        }
    }

    static function apush<T>(a:Array<T>, t:T) {
        a.push(t);
        return a;
    }

    static function aunshift<T>(a:Array<T>, t:T) {
        a.unshift(t);
        return a;
    }

    function psep<T>(sep:TokenKind, f:Void->T):Array<T> {
        var acc = [];
        while(true) {
            try {
                acc.push(f());
                switch stream {
                    case [{kind: sep2} && sep2 == sep]:
                }
            } catch(e:hxparse.NoMatch<Dynamic>) {
                break;
            }
        }
        return acc;
    }

    function ident() {
        return switch stream {
            case [{kind: TkConst(CIdent(i)),pos:p}]: { name: i, pos: p};
        }
    }

    function dollarIdent() {
        return switch stream {
            case [{kind: TkConst(CIdent(i)),pos:p}]: { name: i, pos: p};
            case [{kind: TkDollar(i), pos:p}]: { name: "$" + i, pos: p};
        }
    }

    function dollarIdentMacro(pack:Array<String>) {
        return switch stream {
            case [{kind: TkConst(CIdent(i)),pos:p}]: { name: i, pos: p};
            case [{kind: TkDollar(i), pos:p}]: { name: "$" + i, pos: p};
            case [{kind: TkKeyword(KwMacro), pos: p} && pack.length > 0]: { name: "macro", pos: p };
            case [{kind: TkKeyword(KwExtern), pos: p} && pack.length > 0]: { name: "extern", pos: p };
        }
    }

    function lowerIdentOrMacro() {
        return switch stream {
            case [{kind: TkConst(CIdent(i))} && isLowerIdent(i)]: i;
            case [{kind: TkKeyword(KwMacro)}]: "macro";
            case [{kind: TkKeyword(KwExtern)}]: "extern";
        }
    }

    function anyEnumIdent() {
        return switch stream {
            case [i = ident()]: i;
            case [{kind: TkKeyword(k), pos:p}]: {name:k.getName().toLowerCase(), pos:p};
        }
    }

    function propertyIdent() {
        return switch stream {
            case [i = ident()]: i.name;
            case [{kind: TkKeyword(KwDynamic)}]: "dynamic";
            case [{kind: TkKeyword(KwDefault)}]: "default";
            case [{kind: TkKeyword(KwNull)}]: "null";
        }
    }

    function comma() {
        return switch stream {
            case [{kind: TkComma}]:
        }
    }

    function semicolon() {
        return if (last.kind == TkBraceClose) {
            switch stream {
                case [{kind: TkSemicolon, pos:p}]: p;
                case _: last.pos;
            }
        } else switch stream {
            case [{kind: TkSemicolon, pos:p}]: p;
            case _:
                var pos = last.pos;
                if (doResume)
                    pos
                else
                    throw new ParserError(MissingSemicolon, pos);
            }
    }

    function parseFile() {
        return switch stream {
            case [{kind: TkKeyword(KwPackage)}, p = parsePackage(), _ = semicolon(), l = parseTypeDecls(p,[]), {kind: TkEof}]:
                { pack: p, decls: l };
            case [l = parseTypeDecls([],[]), {kind: TkEof}]:
                { pack: [], decls: l };
        }
    }

    function parseTypeDecls(pack:Array<String>, acc:Array<TypeDecl>) {
        return switch stream {
            case [ v = parseTypeDecl(), l = parseTypeDecls(pack,apush(acc,v)) ]:
                l;
            case _: acc;
        }
    }

    function parseTypeDecl() {
        return switch stream {
            case [{kind: TkKeyword(KwImport), pos:p1}]:
                parseImport(p1);
            case [{kind: TkKeyword(KwUsing), pos: p1}, t = parseTypePath(), p2 = semicolon()]:
                {decl: EUsing(t), pos: punion(p1, p2)};
            case [meta = parseMeta(), c = parseCommonFlags()]:
                switch stream {
                    case [flags = parseEnumFlags(), name = typeName(), tl = parseConstraintParams(), {kind: TkBraceOpen}, l = parseRepeat(parseEnum), {kind: TkBraceClose, pos: p2}]:
                        {decl: EEnum({
                            name: name,
                            meta: meta,
                            params: tl,
                            flags: c.map(function(i) return i.e).concat(flags.flags),
                            data: l
                        }), pos: punion(flags.pos,p2)};
                    case [flags = parseClassFlags(), name = typeName(), tl = parseConstraintParams(), hl = parseRepeat(parseClassHerit), {kind: TkBraceOpen}, fl = parseClassFields(false,flags.pos)]:
                        {decl: EClass({
                            name: name,
                            meta: meta,
                            params: tl,
                            flags: c.map(function(i) return i.c).concat(flags.flags).concat(hl),
                            data: fl.fields
                        }), pos: punion(flags.pos,fl.pos)};
                    case [{kind: TkKeyword(KwTypedef), pos: p1}, name = typeName(), tl = parseConstraintParams(), {kind: TkBinop(OpAssign), pos: p2}, t = parseComplexType()]:
                        switch stream {
                            case [{kind: TkSemicolon}]:
                            case _:
                        }
                        { decl: ETypedef({
                            name: name,
                            meta: meta,
                            params: tl,
                            flags: c.map(function(i) return i.e),
                            data: t
                        }), pos: punion(p1,p2)};
                    case [{kind: TkKeyword(KwAbstract), pos:p1}, name = typeName(), tl = parseConstraintParams(), st = parseAbstractSubtype(), sl = parseRepeat(parseAbstractRelations), {kind: TkBraceOpen}, fl = parseClassFields(false, p1)]:
                        var flags = c.map(function(flag) return switch(flag.e) { case EPrivate: APrivAbstract; case EExtern: AExtern; });
                        if (st != null) {
                            flags.push(AIsType(st));
                        }
                        { decl: EAbstract({
                            name: name,
                            meta: meta,
                            params: tl,
                            flags: flags.concat(sl),
                            data: fl.fields
                        }), pos: punion(p1, fl.pos)};
                }
        }
    }

    function parseClass(meta:Metadata, cflags:Array<{fst: ClassFlag, snd:String}>, needName:Bool) {
        var optName = if (needName) typeName else function() {
            var t = parseOptional(typeName);
            return t == null ? "" : t;
        }
        return switch stream {
            case [flags = parseClassFlags(), name = optName(), tl = parseConstraintParams(), hl = psep(TkComma,parseClassHerit), {kind: TkBraceOpen}, fl = parseClassFields(false,flags.pos)]:
                { decl: EClass({
                    name: name,
                    meta: meta,
                    params: tl,
                    flags: cflags.map(function(i) return i.fst).concat(flags.flags).concat(hl),
                    data: fl.fields
                }), pos: punion(flags.pos,fl.pos)};
        }
    }

    function parseImport(p1:Position) {
        var acc = switch stream {
            case [{kind: TkConst(CIdent(name)), pos:p}]: [{pack:name, pos:p}];
            case _: unexpected();
        }
        while(true) {
            switch stream {
                case [{kind: TkDot}]:
                    switch stream {
                        case [{kind: TkConst(CIdent(k)), pos: p}]:
                            acc.push({pack:k,pos:p});
                        case [{kind: TkKeyword(KwMacro), pos:p}]:
                            acc.push({pack:"macro",pos:p});
                        case [{kind: TkKeyword(KwExtern), pos:p}]:
                            acc.push({pack:"extern",pos:p});
                        case [{kind: TkBinop(OpMult)}, {kind: TkSemicolon, pos:p2}]:
                            return {
                                decl: EImport(acc, IAll),
                                pos: p2
                            }
                        case _: unexpected();
                    }
                case [{kind: TkSemicolon, pos:p2}]:
                    return {
                        decl: EImport(acc, INormal),
                        pos: p2
                    }
                case [{kind: TkKeyword(KwIn) | TkConst(CIdent('as'))}, {kind: TkConst(CIdent(name))}, {kind: TkSemicolon, pos:p2}]:
                    return {
                        decl: EImport(acc, IAsName(name)),
                        pos: p2
                    }
                case _: unexpected();
            }
        }
    }

    function parseAbstractRelations() {
        return switch stream {
            case [{kind: TkConst(CIdent("to"))}, t = parseComplexType()]: AToType(t);
            case [{kind: TkConst(CIdent("from"))}, t = parseComplexType()]: AFromType(t);
        }
    }

    function parseAbstractSubtype() {
        return switch stream {
            case [{kind: TkParenOpen}, t = parseComplexType(), {kind: TkParenClose}]: t;
            case _: null;
        }
    }

    function parsePackage() {
        return psep(TkDot, lowerIdentOrMacro);
    }

    function parseClassFields(tdecl:Bool, p1:Position):{fields:Array<Field>, pos:Position} {
        var l = parseClassFieldResume(tdecl);
        var p2 = switch stream {
            case [{kind: TkBraceClose, pos: p2}]:
                p2;
            case _: unexpected();
        }
        return {
            fields: l,
            pos: p2
        }
    }

    function parseClassFieldResume(tdecl:Bool):Array<Field> {
        return parseRepeat(parseClassField);
    }

    function parseCommonFlags():Array<{c:ClassFlag, e:EnumFlag}> {
        return switch stream {
            case [{kind: TkKeyword(KwPrivate)}, l = parseCommonFlags()]: apush(l, {c:HPrivate, e:EPrivate});
            case [{kind: TkKeyword(KwExtern)}, l = parseCommonFlags()]: apush(l, {c:HExtern, e:EExtern});
            case _: [];
        }
    }

    function parseMetaParams(pname:Position) {
        return switch stream {
            case [{kind: TkParenOpen, pos:p} && p.min == pname.max, params = psep(TkComma, expr), {kind: TkParenClose}]: params;
            case _: [];
        }
    }

    function parseMetaEntry() {
        return switch stream {
            case [{kind: TkAt}, name = metaName(), params = parseMetaParams(name.pos)]: {name: name.name, params: params, pos: name.pos};
        }
    }

    function parseMeta() {
        return switch stream {
            case [entry = parseMetaEntry()]: apush(parseMeta(), entry);
            case _: [];
        }
    }

    function metaName() {
        return switch stream {
            case [{kind: TkConst(CIdent(i)), pos:p}]: {name: i, pos: p};
            case [{kind: TkKeyword(k), pos:p}]: {name: KeywordPrinter.toString(k), pos:p};
            case [{kind: TkColon}]:
                switch stream {
                    case [{kind: TkConst(CIdent(i)), pos:p}]: {name: ':$i', pos: p};
                    case [{kind: TkKeyword(k), pos:p}]: {name: ":" + KeywordPrinter.toString(k), pos:p};
                }
        }
    }

    function parseEnumFlags() {
        return switch stream {
            case [{kind: TkKeyword(KwEnum), pos:p}]: {flags: [], pos: p};
        }
    }

    function parseClassFlags() {
        return switch stream {
            case [{kind: TkKeyword(KwClass), pos:p}]: {flags: [], pos: p};
            case [{kind: TkKeyword(KwInterface), pos:p}]: {flags: apush([],HInterface), pos: p};
        }
    }

    function parseTypeHint() {
        return switch stream {
            case [{kind: TkColon}, t = parseComplexType()]: t;
            case _: null;
        }
    }

    function parseTypeOpt() {
        return switch stream {
            case [t = parseTypeHint()]: t;
            case _: null;
        }
    }

    function parseComplexType() {
        var t = parseComplexTypeInner();
        return parseComplexTypeNext(t);
    }

    function parseStructuralExtension() {
        return switch stream {
            case [{kind: TkBinop(OpGt)}, t = parseTypePath(), {kind: TkComma}]: t;
        }
    }

    function parseComplexTypeInner():ComplexType {
        return switch stream {
            case [{kind: TkParenOpen}, t = parseComplexType(), {kind: TkParenClose}]: TParent(t);
            case [{kind: TkBraceOpen, pos: p1}]:
                switch stream {
                    case [l = parseTypeAnonymous(false)]: TAnonymous(l);
                    case [t = parseStructuralExtension()]:
                        var tl = parseRepeat(parseStructuralExtension);
                        tl.unshift(t);
                        switch stream {
                            case [l = parseTypeAnonymous(false)]: TExtend(tl,l);
                            case [fl = parseClassFields(true, p1)]: TExtend(tl, fl.fields);
                            case _: unexpected();
                        }
                    case [l = parseClassFields(true, p1)]: TAnonymous(l.fields);
                    case _: unexpected();
                }
            case [{kind: TkQuestion}, t = parseComplexTypeInner()]:
                TOptional(t);
            case [t = parseTypePath()]:
                TPath(t);
        }
    }

    function parseTypePath() {
        return parseTypePath1([]);
    }

    function parseTypePath1(pack:Array<String>) {
        return switch stream {
            case [ident = dollarIdentMacro(pack)]:
                if (isLowerIdent(ident.name)) {
                    switch stream {
                        case [{kind: TkDot}]:
                            parseTypePath1(apush(pack, ident.name));
                        case [{kind: TkSemicolon}]:
                            throw new ParserError(Custom("Type name should start with an uppercase letter"), ident.pos);
                        case _: unexpected();
                    }
                } else {
                    var sub = switch stream {
                        case [{kind: TkDot}]:
                            switch stream {
                                case [{kind: TkConst(CIdent(name))} && !isLowerIdent(name)]: name;
                                case _: unexpected();
                            }
                        case _:
                            null;
                    }
                    var params = switch stream {
                        case [{kind: TkBinop(OpLt)}, l = psep(TkComma, parseTypePathOrConst), {kind: TkBinop(OpGt)}]: l;
                        case _: [];
                    }
                    {
                        pack: pack,
                        name: ident.name,
                        params: params,
                        sub: sub
                    }
                }
        }
    }

    function typeName() {
        return switch stream {
            case [{kind: TkConst(CIdent(name)), pos:p}]:
                if (isLowerIdent(name)) throw new ParserError(Custom("Type name should start with an uppercase letter"), p);
                else name;
        }
    }

    function parseTypePathOrConst() {
        return switch stream {
            case [{kind: TkBracketOpen, pos: p1}, l = parseArrayDecl(), {kind: TkBracketClose, pos:p2}]: TPExpr({expr: EArrayDecl(l), pos:punion(p1,p2)});
            case [t = parseComplexType()]: TPType(t);
            case [{kind: TkConst(c), pos:p}]: TPExpr({expr:EConst(c), pos:p});
            case [e = expr()]: TPExpr(e);
            case _: unexpected();
        }
    }

    function parseComplexTypeNext(t:ComplexType) {
        return switch stream {
            case [{kind: TkArrow}, t2 = parseComplexType()]:
                switch(t2) {
                    case TFunction(args,r):
                        TFunction(apush(args,t),r);
                    case _:
                        TFunction([t],t2);
                }
            case _: t;
        }
    }

    function parseTypeAnonymous(opt:Bool):Array<Field> {
        return switch stream {
            case [id = ident(), t = parseTypeHint()]:
                function next(p2,acc) {
                    var t = !opt ? t : switch(t) {
                        case TPath({pack:[], name:"Null"}): t;
                        case _: TPath({pack:[], name:"Null", sub:null, params:[TPType(t)]});
                    }
                    return aunshift(acc, {
                        name: id.name,
                        meta: opt ? [{name:":optional",params:[], pos:id.pos}] : [],
                        access: [],
                        kind: FVar(t,null),
                        pos: punion(id.pos, p2)
                    });
                }
                switch stream {
                    case [{kind: TkBraceClose, pos:p2}]: next(p2, []);
                    case [{kind: TkComma, pos:p2}]:
                        switch stream {
                            case [{kind: TkBraceClose}]: next(p2, []);
                            case [l = parseTypeAnonymous(false)]: next(p2, l);
                            case _: unexpected();
                        }
                    case _: unexpected();
                }
            case [{kind: TkQuestion} && !opt]: parseTypeAnonymous(true);
        }
    }

    function parseEnum() {
        var meta = parseMeta();
        return switch stream {
            case [name = anyEnumIdent(), params = parseConstraintParams()]:
                var args = switch stream {
                    case [{kind: TkParenOpen}, l = psep(TkComma, parseEnumParam), {kind: TkParenClose}]: l;
                    case _: [];
                }
                var t = parseTypeOpt();
                var p2 = switch stream {
                    case [p = semicolon()]: p;
                    case _: unexpected();
                }
                {
                    name: name.name,
                    meta: meta,
                    args: args,
                    params: params,
                    type: t,
                    pos: punion(name.pos, p2)
                }
        }
    }

    function parseEnumParam() {
        return switch stream {
            case [{kind: TkQuestion}, name = ident(), t = parseTypeHint()]: { name: name.name, opt: true, type: t};
            case [name = ident(), t = parseTypeHint()]: { name: name.name, opt: false, type: t };
        }
    }

    function parseClassField():Field {
        return switch stream {
            case [meta = parseMeta(), al = parseCfRights(true,[])]:
                var data = switch stream {
                    case [{kind: TkKeyword(KwVar), pos:p1}, name = ident()]:
                        switch stream {
                            case [{kind: TkParenOpen}, i1 = propertyIdent(), {kind: TkComma}, i2 = propertyIdent(), {kind: TkParenClose}]:
                                var t = parseTypeOpt();
                                var e = switch stream {
                                    case [{kind: TkBinop(OpAssign)}, e = toplevelExpr(), p2 = semicolon()]: { expr: e, pos: p2 };
                                    case [{kind: TkSemicolon, pos:p2}]: { expr: null, pos: p2 };
                                    case _: unexpected();
                                }
                                {
                                    name: name.name,
                                    pos: punion(p1,e.pos),
                                    kind: FProp(i1,i2,t,e.expr)
                                }
                            case [t = parseTypeOpt()]:
                                var e = switch stream {
                                    case [{kind: TkBinop(OpAssign)}, e = toplevelExpr(), p2 = semicolon()]: { expr: e, pos: p2 };
                                    case [{kind: TkSemicolon, pos:p2}]: { expr: null, pos: p2 };
                                    case _: unexpected();
                                }
                                {
                                    name: name.name,
                                    pos: punion(p1,e.pos),
                                    kind: FVar(t,e.expr)
                                }
                        }
                    case [{kind: TkKeyword(KwFunction), pos:p1}, name = parseFunName(), pl = parseConstraintParams(), {kind: TkParenOpen}, al = psep(TkComma, parseFunParam), {kind: TkParenClose}, t = parseTypeOpt()]:
                        var e = switch stream {
                            case [e = toplevelExpr(), _ = semicolon()]:
                                { expr: e, pos: e.pos };
                            case [{kind: TkSemicolon,pos:p}]:
                                { expr: null, pos: p}
                            case _: unexpected();
                        }
                        var f = {
                            params: pl,
                            args: al,
                            ret: t,
                            expr: e.expr
                        }
                        {
                            name: name,
                            pos: punion(p1, e.pos),
                            kind: FFun(f)
                        }
                    case _:
                        if (al.length == 0)
                            throw noMatch();
                        else
                            unexpected();
                }
            {
                name: data.name,
                meta: meta,
                access: al,
                pos: data.pos,
                kind: data.kind
            }
        }
    }

    function parseCfRights(allowStatic:Bool, l:Array<Access>) {
        return switch stream {
            case [{kind: TkKeyword(KwStatic)} && allowStatic, l = parseCfRights(false, apush(l, AStatic))]: l;
            case [{kind: TkKeyword(KwMacro)}, l = parseCfRights(allowStatic, apush(l, AMacro))]: l;
            case [{kind: TkKeyword(KwPublic)}, l = parseCfRights(allowStatic, apush(l, APublic))]: l;
            case [{kind: TkKeyword(KwPrivate)}, l = parseCfRights(allowStatic, apush(l, APrivate))]: l;
            case [{kind: TkKeyword(KwOverride)}, l = parseCfRights(false, apush(l, AOverride))]: l;
            case [{kind: TkKeyword(KwDynamic)}, l = parseCfRights(allowStatic, apush(l, ADynamic))]: l;
            case [{kind: TkKeyword(KwInline)}, l = parseCfRights(allowStatic, apush(l, AInline))]: l;
            case _: l;
        }
    }

    function parseFunName() {
        return switch stream {
            case [{kind: TkConst(CIdent(name))}]: name;
            case [{kind: TkKeyword(KwNew)}]: "new";
        }
    }

    function parseFunParam() {
        var meta = parseMeta();
        return switch stream {
            case [{kind: TkQuestion}, id = ident(), t = parseTypeOpt(), c = parseFunParamValue()]: { name: id.name, opt: true, type: t, value: c, meta: meta };
            case [id = ident(), t = parseTypeOpt(), c = parseFunParamValue()]: { name: id.name, opt: false, type: t, value: c, meta: meta };

        }
    }

    function parseFunParamValue() {
        return switch stream {
            case [{kind: TkBinop(OpAssign)}, e = toplevelExpr()]: e;
            case _: null;
        }
    }

    function parseFunParamType() {
        return switch stream {
            case [{kind: TkQuestion}, id = ident(), t = parseTypeHint()]: { name: id.name, opt: true, type: t};
            case [ id = ident(), t = parseTypeHint()]: { name: id.name, opt: false, type: t};
        }
    }

    function parseConstraintParams() {
        return switch stream {
            case [{kind: TkBinop(OpLt)}, l = psep(TkComma, parseConstraintParam), {kind: TkBinop((OpGt))}]: l;
            case _: [];
        }
    }

    function parseConstraintParam() {
        return switch stream {
            case [meta = parseMeta(), name = typeName()]:
                var params = [];
                var ctl = switch stream {
                    case [{kind: TkColon}]:
                        switch stream {
                            case [{kind: TkParenOpen}, l = psep(TkComma, parseComplexType), {kind: TkParenClose}]: l;
                            case [t = parseComplexType()]: [t];
                            case _: unexpected();
                        }
                    case _: [];
                }
                {
                    name: name,
                    params: params,
                    constraints: ctl,
                    meta: meta
                }
        }
    }

    function parseClassHerit() {
        return switch stream {
            case [{kind: TkKeyword(KwExtends)}, t = parseTypePath()]: HExtends(t);
            case [{kind: TkKeyword(KwImplements)}, t = parseTypePath()]: HImplements(t);
        }
    }

    function block1() {
        return switch stream {
            case [{kind: TkConst(CIdent(name)), pos:p}]: block2(name, CIdent(name), p);
            case [{kind: TkConst(CString(name)), pos:p}]: block2(quoteIdent(name), CString(name), p);
            case [b = block([])]: EBlock(b);
        }
    }

    function block2(name:String, ident:Constant, p:Position) {
        return switch stream {
            case [{kind: TkColon}, e = expr(), l = parseObjDecl()]:
                l.unshift({field:name, expr:e});
                EObjectDecl(l);
            case _:
                var e = exprNext({expr:EConst(ident), pos: p});
                var _ = semicolon();
                var b = block([e]);
                EBlock(b);
        }
    }

    function block(acc:Array<Expr>) {
        try {
            var e = parseBlockElt();
            return block(apush(acc,e));
        } catch(e:hxparse.NoMatch<Dynamic>) {
            return acc;
        }
    }

    function parseBlockElt() {
        return switch stream {
            case [{kind: TkKeyword(KwVar), pos:p1}, vl = psep(TkComma, parseVarDecl), p2 = semicolon()]: { expr: EVars(vl), pos:punion(p1,p2)};
            case [e = expr(), _ = semicolon()]: e;
        }
    }

    function parseObjDecl() {
        var acc = [];
        while(true) {
            switch stream {
                case [{kind: TkComma}]:
                    switch stream {
                        case [id = ident(), {kind: TkColon}, e = expr()]:
                            acc.push({field:id.name, expr: e});
                        case [{kind: TkConst(CString(name))}, {kind: TkColon}, e = expr()]:
                            //apush(l,{field:quoteIdent(name), expr: e});
                            acc.push({field:quoteIdent(name), expr: e});
                        case _:
                            break;
                    }
                case _:
                    break;
            }
        }
        return acc;
    }

    function parseArrayDecl() {
        var acc = [];
        var br = false;
        while(true) {
            switch stream {
                case [e = expr()]:
                    acc.push(e);
                    switch stream {
                        case [{kind: TkComma}]:
                        case _: br = true;
                    }
                case _: br = true;
            }
            if (br) break;
        }
        return acc;
    }

    function parseVarDecl() {
        return switch stream {
            case [id = dollarIdent(), t = parseTypeOpt()]:
                switch stream {
                    case [{kind: TkBinop(OpAssign)}, e = expr()]: { name: id.name, type: t, expr: e};
                    case _: { name: id.name, type:t, expr: null};
                }
        }
    }

    function inlineFunction() {
        return switch stream {
            case [{kind: TkKeyword(KwInline)}, {kind: TkKeyword(KwFunction), pos:p1}]: { isInline: true, pos: p1};
            case [{kind: TkKeyword(KwFunction), pos: p1}]: { isInline: false, pos: p1};
        }
    }

    function reify(inMacro:Bool) {
        var reificator = new Reificator(inMacro);
        return {
            toExpr: function(e:Expr):Expr{
                return reificator.toExpr(e,e.pos);
            },
            toType: reificator.toCType,
            toTypeDef: reificator.toTypeDef
        };
    }

    function reifyExpr(e:Expr) {
        var toExpr = reify(inMacro).toExpr;
        var e = toExpr(e);
        return { expr: ECheckType(e, TPath( {pack:["haxe","macro"], name:"Expr", sub:null, params: []})), pos: e.pos};
    }

    function parseMacroExpr(p:Position) {
        return switch stream {
            case [{kind: TkColon}, t = parseComplexType()]:
                var toType = reify(inMacro).toType;
                var t = toType(t,p);
                { expr: ECheckType(t, TPath( {pack:["haxe","macro"], name:"Expr", sub:"ComplexType", params: []})), pos: p};
            case [{kind: TkKeyword(KwVar), pos:p1}, vl = psep(TkComma, parseVarDecl)]:
                reifyExpr({expr:EVars(vl), pos:p1});
            case [d = parseClass([],[],false)]:
                var toType = reify(inMacro).toTypeDef;
                { expr: ECheckType(toType(d), TPath( {pack:["haxe","macro"], name:"Expr", sub:"TypeDefinition", params: []})), pos: p};
            case [e = secureExpr()]:
                reifyExpr(e);
        }
    }

    public function expr():Expr {
        return switch stream {
            case [meta = parseMetaEntry()]:
                makeMeta(meta.name, meta.params, secureExpr(), meta.pos);
            case [{kind: TkBraceOpen, pos:p1}, b = block1(), {kind: TkBraceClose, pos:p2}]:
                var e = { expr: b, pos: punion(p1, p2)};
                switch(b) {
                    case EObjectDecl(_): exprNext(e);
                    case _: e;
                }
            case [{kind: TkKeyword(KwMacro), pos:p}]:
                parseMacroExpr(p);
            case [{kind: TkKeyword(KwVar), pos: p1}, v = parseVarDecl()]: { expr: EVars([v]), pos: p1};
            case [{kind: TkConst(c), pos:p}]: exprNext({expr:EConst(c), pos:p});
            case [{kind: TkKeyword(KwThis), pos:p}]: exprNext({expr: EConst(CIdent("this")), pos:p});
            case [{kind: TkKeyword(KwTrue), pos:p}]: exprNext({expr: EConst(CIdent("true")), pos:p});
            case [{kind: TkKeyword(KwFalse), pos:p}]: exprNext({expr: EConst(CIdent("false")), pos:p});
            case [{kind: TkKeyword(KwNull), pos:p}]: exprNext({expr: EConst(CIdent("null")), pos:p});
            case [{kind: TkKeyword(KwCast), pos:p1}]:
                switch stream {
                    case [{kind: TkParenOpen, pos:pp}, e = expr()]:
                        switch stream {
                            case [{kind: TkComma}, t = parseComplexType(), {kind: TkParenClose, pos:p2}]: exprNext({expr:ECast(e,t), pos: punion(p1,p2)});
                            case [t = parseTypeHint(), {kind: TkParenClose, pos:p2}]:
                                var pu = punion(p1, p2);
                                var ep = {expr: EParenthesis({expr: ECheckType(e, t), pos: pu}), pos: pu};
                                exprNext({expr: ECast(ep, null), pos: punion(p1, pu)});
                            case [{kind: TkParenClose, pos:p2}]:
                                var ep = exprNext({expr: EParenthesis(e), pos: punion(pp, p2)});
                                exprNext({expr:ECast(ep,null),pos:punion(p1,ep.pos)});
                            case _: unexpected();
                        }
                    case [e = secureExpr()]: exprNext({expr:ECast(e,null), pos:punion(p1, e.pos)});
                }
            case [{kind: TkKeyword(KwThrow), pos:p}, e = expr()]: { expr: EThrow(e), pos: p};
            case [{kind: TkKeyword(KwNew), pos:p1}, t = parseTypePath(), {kind: TkParenOpen, pos:_}]:
                switch stream {
                    case [al = psep(TkComma, expr), {kind: TkParenClose, pos:p2}]: exprNext({expr:ENew(t,al), pos:punion(p1, p2)});
                    case _: unexpected();
                }
            case [{kind: TkParenOpen, pos: p1}, e = expr()]:
                switch stream {
                    case [{kind: TkParenClose, pos:p2}]: exprNext({expr:EParenthesis(e), pos:punion(p1, p2)});
                    case [t = parseTypeHint(), {kind: TkParenClose, pos:p2}]: exprNext({expr:ECheckType(e, t), pos:punion(p1, p2)});
                    case _: unexpected();
                }
            case [{kind: TkBracketOpen, pos:p1}, l = parseArrayDecl(), {kind: TkBracketClose, pos:p2}]: exprNext({expr: EArrayDecl(l), pos:punion(p1,p2)});
            case [inl = inlineFunction(), name = parseOptional(dollarIdent), pl = parseConstraintParams(), {kind: TkParenOpen}, al = psep(TkComma,parseFunParam), {kind: TkParenClose}, t = parseTypeOpt()]:
                function make(e) {
                    var f = {
                        params: pl,
                        ret: t,
                        args: al,
                        expr: e
                    };
                    return { expr: EFunction(name == null ? null : inl.isInline ? "inline_" + name.name : name.name, f), pos: punion(inl.pos, e.pos)};
                }
                exprNext(make(secureExpr()));
            case [{kind: TkPlusPlus, pos:p1}, e = expr()]: makeUnop(OpIncrement,e,p1);
            case [{kind: TkMinusMinus, pos:p1}, e = expr()]: makeUnop(OpDecrement,e,p1);
            case [{kind: TkTilde, pos:p1}, e = expr()]: makeUnop(OpNegBits,e,p1);
            case [{kind: TkExclamation, pos:p1}, e = expr()]: makeUnop(OpNot,e,p1);
            case [{kind: TkBinop(OpSub), pos:p1}, e = expr()]:
                function neg(s:String) {
                    return s.charCodeAt(0) == '-'.code
                        ? s.substr(1)
                        : "-" + s;
                }
                switch (makeUnop(OpNeg,e,p1)) {
                    case {expr:EUnop(OpNeg,false,{expr:EConst(CInt(i))}), pos:p}:
                        {expr:EConst(CInt(neg(i))), pos:p};
                    case {expr:EUnop(OpNeg,false,{expr:EConst(CFloat(j))}), pos:p}:
                        {expr:EConst(CFloat(neg(j))), pos:p};
                    case e: e;
                }
            case [{kind: TkKeyword(KwFor), pos:p}, {kind: TkParenOpen}, it = expr(), {kind: TkParenClose}]:
                var e = secureExpr();
                { expr: EFor(it,e), pos:punion(p, e.pos)};
            case [{kind: TkKeyword(KwIf), pos:p}, {kind: TkParenOpen}, cond = expr(), {kind: TkParenClose}, e1 = expr()]:
                var e2 = switch stream {
                    case [{kind: TkKeyword(KwElse)}, e2 = expr()]: e2;
                    case _:
                        switch [peek(0),peek(1)] {
                            case [{kind: TkSemicolon}, {kind: TkKeyword(KwElse)}]:
                                junk();
                                junk();
                                secureExpr();
                            case _: null;
                        }
                }
                { expr: EIf(cond,e1,e2), pos:punion(p, e2 == null ? e1.pos : e2.pos)};
            case [{kind: TkKeyword(KwReturn), pos:p}, e = parseOptional(expr)]: { expr: EReturn(e), pos: e == null ? p : punion(p,e.pos)};
            case [{kind: TkKeyword(KwBreak), pos:p}]: { expr: EBreak, pos: p };
            case [{kind: TkKeyword(KwContinue), pos:p}]: { expr: EContinue, pos: p};
            case [{kind: TkKeyword(KwWhile), pos:p1}, {kind: TkParenOpen}, cond = expr(), {kind: TkParenClose}]:
                var e = secureExpr();
                { expr: EWhile(cond, e, true), pos: punion(p1, e.pos)};
            case [{kind: TkKeyword(KwDo), pos:p1}, e = expr(), {kind: TkKeyword(KwWhile)}, {kind: TkParenOpen}, cond = expr(), {kind: TkParenClose}]: { expr: EWhile(cond,e,false), pos:punion(p1, e.pos)};
            case [{kind: TkKeyword(KwSwitch), pos:p1}, e = expr(), {kind: TkBraceOpen}, cases = parseSwitchCases(), {kind: TkBraceClose, pos:p2}]:
                { expr: ESwitch(e,cases.cases,cases.def), pos:punion(p1,p2)};
            case [{kind: TkKeyword(KwTry), pos:p1}, e = expr(), cl = parseRepeat(parseCatch)]:
                { expr: ETry(e,cl), pos:p1};
            case [{kind: TkKeyword(KwUntyped), pos:p1}, e = expr()]: { expr: EUntyped(e), pos:punion(p1,e.pos)};
            case [{kind: TkDollar(v), pos:p}]: exprNext({expr:EConst(CIdent("$" + v)), pos:p});
        }
    }

    inline function toplevelExpr():Expr {
        return expr();
    }

    function exprNext(e1:Expr):Expr {
        return switch stream {
            case [{kind: TkDot, pos:p}]:
                switch stream {
                    case [{kind: TkDollar(v), pos:p2}]:
                        exprNext({expr:EField(e1, "$" + v), pos:punion(e1.pos, p2)});
                    case [{kind: TkConst(CIdent(f)), pos:p2} && p.max == p2.min]:
                        exprNext({expr:EField(e1,f), pos:punion(e1.pos,p2)});
                    case [{kind: TkKeyword(KwMacro), pos:p2} && p.max == p2.min]:
                        exprNext({expr:EField(e1,"macro"), pos:punion(e1.pos,p2)});
                    case [{kind: TkKeyword(KwExtern), pos:p2} && p.max == p2.min]:
                        exprNext({expr:EField(e1,"extern"), pos:punion(e1.pos,p2)});
                    case _:
                        switch(e1) {
                            case {expr: EConst(CInt(v)), pos:p2} if (p2.max == p.min):
                                exprNext({expr:EConst(CFloat(v + ".")), pos:punion(p,p2)});
                            case _: unexpected();
                        }
                }
            case [{kind: TkParenOpen, pos:_}]:
                switch stream {
                    case [params = parseCallParams(), {kind: TkParenClose, pos:p2}]:
                        exprNext({expr:ECall(e1,params),pos:punion(e1.pos,p2)});
                    case _: unexpected();
                }
            case [{kind: TkBracketOpen}, e2 = expr(), {kind: TkBracketClose, pos:p2}]:
                exprNext({expr:EArray(e1,e2), pos:punion(e1.pos,p2)});
            case [{kind: TkBinop(OpGt)}]:
                switch stream {
                    case [{kind: TkBinop(OpGt)}]:
                        switch stream {
                            case [{kind: TkBinop(OpGt)}]:
                                switch stream {
                                    case [{kind: TkBinop(OpAssign)}, e2 = expr()]:
                                        makeBinop(OpAssignOp(OpUShr),e1,e2);
                                    case [e2 = secureExpr()]: makeBinop(OpUShr,e1,e2);
                                }
                            case [{kind: TkBinop(OpAssign)}, e2 = expr()]:
                                makeBinop(OpAssignOp(OpShr),e1,e2);
                            case [e2 = secureExpr()]:
                                makeBinop(OpShr,e1,e2);
                        }
                    case [{kind: TkBinop(OpAssign)}]:
                        makeBinop(OpGte,e1,secureExpr());
                    case [e2 = secureExpr()]:
                        makeBinop(OpGt,e1,e2);
                }
            case [{kind: TkBinop(op)}, e2 = expr()]:
                makeBinop(op,e1,e2);
            case [{kind: TkQuestion}, e2 = expr(), {kind: TkColon}, e3 = expr()]:
                { expr: ETernary(e1,e2,e3), pos: punion(e1.pos, e3.pos)};
            case [{kind: TkKeyword(KwIn)}, e2 = expr()]:
                {expr:EIn(e1,e2), pos:punion(e1.pos, e2.pos)};
            case [{kind: TkPlusPlus, pos:p} && isPostfix(e1)]:
                exprNext({expr:EUnop(OpIncrement,true,e1), pos:punion(e1.pos, p)});
            case [{kind: TkMinusMinus, pos:p} && isPostfix(e1)]:
                exprNext({expr:EUnop(OpDecrement,true,e1), pos:punion(e1.pos, p)});
            case [{kind: TkBraceOpen, pos:p1} && isDollarIdent(e1), eparam = expr(), {kind: TkBraceClose,pos:p2}]:
                switch (e1.expr) {
                    case EConst(CIdent(n)):
                        exprNext({expr: EMeta({name:n, params:[], pos:e1.pos},eparam), pos:punion(p1,p2)});
                    case _: throw false;
                }
            case _: e1;
        }
    }

    function parseGuard() {
        return switch stream {
            case [{kind: TkKeyword(KwIf)}, {kind: TkParenOpen}, e = expr(), {kind: TkParenClose}]:
                e;
        }
    }

    function parseSwitchCases() {
        var cases = [];
        var def = null;
        function caseBlock(b:Array<Expr>, p:Position) {
            return if (b.length == 0) {
                null;
            } else switch(b) {
                case [e = macro $b{el}]: e;
                case _: { expr: EBlock(b), pos: p};
            }
        }
        while(true) {
            switch stream {
                case [{kind: TkKeyword(KwDefault), pos:p1}, {kind: TkColon}]:
                    var b = block([]);
                    var e = caseBlock(b, p1);
                    if (e == null) {
                        e = { expr: null, pos: p1 };
                    }
                    if (def != null) {
                        throw new ParserError(DuplicateDefault, p1);
                    }
                    def = e;
                case [{kind: TkKeyword(KwCase), pos:p1}, el = psep(TkComma,expr), eg = parseOptional(parseGuard), {kind: TkColon}]:
                    var b = block([]);
                    var e = caseBlock(b, p1);
                    cases.push({values:el,guard:eg,expr:e});
                case _:
                    break;
            }
        }
        return {
            cases: cases,
            def: def
        }
    }

    function parseCatch() {
        return switch stream {
            case [{kind: TkKeyword(KwCatch), pos:p}, {kind: TkParenOpen}, id = ident(), ]:
                switch stream {
                    case [t = parseTypeHint(), {kind: TkParenClose}]:
                        {
                            name: id.name,
                            type: t,
                            expr: secureExpr()
                        }
                    case _:
                        throw new ParserError(MissingType, p);
                }
        }
    }

    function parseCallParams() {
        var ret = [];
        switch stream {
            case [e = expr()]: ret.push(e);
            case _: return [];
        }
        while(true) {
            switch stream {
                case [{kind: TkComma}, e = expr()]: ret.push(e);
                case _: break;
            }
        }
        return ret;
    }

    function secureExpr() {
        return expr();
    }
}

private class Reificator{

    var curPos:Null<Expr>;
    var inMacro:Bool;

    public function new(inMacro:Bool){
        this.curPos = null;
        this.inMacro = inMacro;
    }

    function mkEnum(ename:String, name:String, vl:Array<Expr>, p:Position):Expr{
        var constr:Expr = {expr:EConst(CIdent(name)), pos:p};
        switch (vl){
            case []: return constr;
            case _ : return {expr:ECall(constr, vl),pos:p};
        }
    }

    function toConst(c:Constant, p:Position):Expr{
        function cst(n:String, v:String):Expr{
            return mkEnum("Constant", n, [{expr:EConst(CString(v)),pos:p}], p);
        }

        switch(c){
            case CInt(i): return cst("CInt", i);
            case CString(s): return cst("CString", s);
            case CFloat(s): return cst("CFloat", s);
            case CIdent(s): return cst("CIdent", s);
            case CRegexp(r,o): return mkEnum("Constant", "CRegexp", [{expr:EConst(CString(r)),pos:p},{expr:EConst(CString(o)),pos:p}], p);
        }
    }

    function toBinop(o:Binop,p:Position):Expr{
        function op(n:String):Expr{
            return mkEnum("Binop", n, [], p);
        }

        switch(o){
            case OpAdd: return op("OpAdd");
            case OpMult: return op("OpMult");
            case OpDiv: return op("OpDiv");
            case OpSub: return op("OpSub");
            case OpAssign: return op("OpAssign");
            case OpEq: return op("OpEq");
            case OpNotEq: return op("OpNotEq");
            case OpGt: return op("OpGt");
            case OpGte: return op("OpGte");
            case OpLt: return op("OpLt");
            case OpLte: return op("OpLte");
            case OpAnd: return op("OpAnd");
            case OpOr: return op("OpOr");
            case OpXor: return op("OpXor");
            case OpBoolAnd: return op("OpBoolAnd");
            case OpBoolOr: return op("OpBoolOr");
            case OpShl: return op("OpShl");
            case OpShr: return op("OpShr");
            case OpUShr: return op("OpUShr");
            case OpMod: return op("OpMod");
            case OpAssignOp(o): return mkEnum("Binop", "OpAssignOp", [toBinop(o, p)], p);
            case OpInterval: return op("OpInterval");
            case OpArrow: return op("OpArrow");
        }
    }

    function toString(s:String, p:Position):Expr{
        var len = s.length;
        if (len>1 && s.charAt(0) == '$') return {expr:EConst(CIdent(s.substr(1))),pos:p};
        else return {expr:EConst(CString(s)),pos:p};
    }

    function toArray<T>(f:T->Position->Expr, a:Array<T>, p:Position):Expr{
        var vals = [];
        for (v in a){
            vals.push(f(v,p));
        }

        var e:Expr = {
        pos:p,
        expr:EArrayDecl(vals)
        };
        return e;
    }

    function toNull(p:Position):Expr{
        return {expr:EConst(CIdent("null")),pos:p};
    }

    function toOpt<T>(f:T -> Position -> Expr, v:Null<T>, p:Position):Expr{
        if (v == null) return toNull(p);
        else return f(v, p);
    }

    function toBool(o:Bool, p:Position):Expr{
        var s:String = o?"true":"false";
        return {expr:EConst(CIdent(s)),pos:p};
    }

    function toObj(fields:Array<{field:String, expr:Expr}>, p:Position):Expr{
        return {expr:EObjectDecl(fields),pos:p};
    }

    function toTParam(t:TypeParam, p:Position):Expr{
        var n:String;
        var v:Expr;
        switch(t){
            case TPType(t):
                n = "TPType";
                v = toCType(t, p);
            case TPExpr(e):
                n = "TPExpr";
                v = toExpr(e, p);
        }

        return mkEnum("TypeParam", n, [v], p);
    }

    function toTPath(t:TypePath, p:Position):Expr{
        var fields:Array<{field:String, expr:Expr}> = [
        {field:"pack",   expr:toArray(toString, t.pack, p)},
        {field:"name",   expr:toString(t.name, p)},
        {field:"params", expr:toArray(toTParam, t.params, p)}
        ];
        if(t.sub != null){
            fields.push({field:"sub",expr:toString(t.sub, p)});
        }
        return toObj(fields, p);
    }

    public function toCType(t:ComplexType, p:Position):Expr {
        function ct(n:String, vl:Array<Expr>):Expr {
            return mkEnum("ComplexType", n, vl, p);
        }

        return switch(t){
            case TPath({pack: [], params: [], sub: null, name: n }) if (n.charAt(0) == '$'):
                toString(n, p);
            case TPath(t): ct("TPath", [toTPath(t, p)]);
            case TFunction(args, ret): ct("TFunction", [toArray(toCType, args, p), toCType(ret, p)]);
            case TAnonymous(fields): ct("TAnonymous", [toArray(toCField, fields, p)]);
            case TParent(t): ct("TParent", [toCType(t, p)]);
            case TExtend(tl, fields): ct("TExtend", [toArray(toTPath, tl, p), toArray(toCField, fields, p)]);
            case TOptional(t): ct("TOptional", [toCType(t, p)]);
        }
    }

    function toFun(f:Function, p:Position):Expr{
        function farg(vv:FunctionArg,p:Position):Expr{
            var n = vv.name;
            var o = vv.opt;
            var t = vv.type;
            var e = vv.value;
            var fields:Array<{field:String, expr:Expr}> = [
            {field:"name", expr:toString(n, p)},
            {field:"opt",  expr:toBool(o, p)},
            {field:"type", expr:toOpt(toCType, t, p)}
            ];
            if (e != null){
                fields.push({field:"value", expr:toExpr(e, p)});
            }
            return toObj(fields, p);
        }

        function fparam(t:TypeParamDecl,p:Position):Expr{
            var fields:Array<{field:String, expr:Expr}> = [
            {field:"name",        expr:toString(t.name, p)},
            {field:"constraints", expr:toArray(toCType, t.constraints, p)},
            {field:"params",      expr:toArray(fparam, t.params, p)}
            ];
            return toObj(fields, p);
        }

        var fields:Array<{field:String, expr:Expr}> = [
        {field:"args",   expr:toArray(farg, f.args, p)},
        {field:"ret",    expr:toOpt(toCType, f.ret, p)},
        {field:"expr",   expr:toOpt(toExpr, f.expr, p)},
        {field:"params", expr:toArray(fparam, f.params, p)}
        ];

        return toObj(fields, p);
    }

    function toAccess(a:Access, p:Position):Expr {
        var n:String;
        var n = switch(a){
            case APublic :   "APublic";
            case APrivate :  "APrivate";
            case AStatic :   "AStatic";
            case AOverride : "AOverride";
            case ADynamic :  "ADynamic";
            case AInline :   "AInline";
            case AMacro :    "AMacro";
        }
        return mkEnum("Access", n, [], p);
    }

    function toCField(f:Field, p:Position):Expr {
        var p2:Position = f.pos;

        function toFType(k:FieldType):Expr {
            var n:String;
            var vl:Array<Expr>;
            switch(k){
                case FVar(ct, e): n = "FVar"; vl = [toOpt(toCType, ct, p), toOpt(toExpr, e, p)];
                case FFun(f): n = "FFun"; vl = [toFun(f, p)];
                case FProp(get, set, t, e): n = "FProp"; vl = [toString(get, p), toString(set, p), toOpt(toCType, t, p), toOpt(toExpr, e, p)];
            }
            return mkEnum("FieldType", n, vl, p);
        }

        var fields:Array<{field:String, expr:Expr}> = [];
        fields.push({field:"name", expr:toString(f.name, p)});
        if (f.access != null) fields.push({field:"access", expr:toArray(toAccess, f.access, p)});
        fields.push({field:"kind", expr:toFType(f.kind)});
        fields.push({field:"pos",  expr:toPos(f.pos)});
        if (f.meta != null) fields.push({field:"meta", expr:toMeta(f.meta, p)});

        return toObj(fields, p);
    }

    function toMeta(m:Metadata, p:Position):Expr {
        return toArray(function(me:MetadataEntry, _:Position):Expr {
            var fields:Array<{field:String, expr:Expr}> = [
            {field:"name",   expr:toString(me.name, me.pos)},
            {field:"params", expr:toExprArray(me.params, me.pos)},
            {field:"pos",    expr:toPos(me.pos)}
            ];
            return toObj(fields, me.pos);
        }, m, p);
    }

    function toPos(p:Position):Expr {
        if (curPos != null) return curPos;

        var file:Expr = {expr:EConst(CString(p.file)),         pos:p};
        var pmin:Expr = {expr:EConst(CInt(Std.string(p.min))), pos:p};
        var pmax:Expr = {expr:EConst(CInt(Std.string(p.max))), pos:p};
        if (inMacro)
            return {expr:EUntyped({expr:ECall({expr:EConst(CIdent("$mk_pos")), pos:p}, [file, pmin, pmax]), pos:p}), pos:p};
        else
            return toObj([{field:"file", expr:file}, {field:"min", expr:pmin}, {field:"max", expr:pmax}], p);
    }

    function toExprArray(a:Array<Expr>, p:Position):Expr {
        if (a.length > 0){
            switch(a[0].expr){
            case EMeta(md,e1):
                if (md.name == "$a" && md.params.length == 0){
                    switch(e1.expr){
                    case EArrayDecl(el): return toExprArray(el, p);
                    default: return e1;
                    }
                }
            default:
            }
        }
        return toArray(toExpr, a, p);
    }

    public function toExpr(e:Expr, _:Position):Expr {
        var p = e.pos;
        function expr(n:String, vl:Array<Expr>):Expr {
            var e = mkEnum("ExprDef", n, vl, p);
            return toObj([{field:"expr", expr:e}, {field:"pos", expr:toPos(p)}], p);
        }
        function loop(e:Expr):Expr {
            return toExpr(e, e.pos);
        }
        return switch(e.expr){
            case EConst(CIdent(n)) if (n.charAt(0) == '$' && n.length > 1):
                toString(n, p);
            case EConst(c):
                expr("EConst", [toConst(c, p)]);
            case EArray(e1, e2):
                expr("EArray", [loop(e1), loop(e2)]);
            case EBinop(op, e1, e2):
                expr("EBinop", [toBinop(op, p), loop(e1), loop(e2)]);
            case EField(e, s):
                expr("EField", [loop(e), toString(s, p)]);
            case EParenthesis(e):
                expr("EParenthesis", [loop(e)]);
            case EObjectDecl(fl):
                expr("EObjectDecl", [toArray(function(f:{field:String, expr:Expr}, p2:Position):Expr {return toObj([{field:"field", expr:toString(f.field, p)}, {field:"expr", expr:loop(f.expr)}], p2);}, fl, p)]);
            case EArrayDecl(el):
                expr("EArrayDecl", [toExprArray(el, p)]);
            case ECall(e, el):
                expr("ECall", [loop(e), toExprArray(el, p)]);
            case ENew(t, el):
                expr("ENew", [toTPath(t, p), toExprArray(el, p)]);
            case EUnop(op, isPostfix, e):
                var ops:String;
                switch(op){
                    case OpIncrement: ops = "OpIncrement";
                    case OpDecrement: ops = "OpDecrement";
                    case OpNot: ops = "OpNot";
                    case OpNeg: ops = "OpNeg";
                    case OpNegBits: ops = "OpNegBits";
                }
                var op2 = mkEnum("Unop", ops, [], p);
                expr("EUnop", [op2, toBool(isPostfix, p), loop(e)]);
            case EVars(vl):
                expr("EVars", [toArray(function(vv:Var, p:Position):Expr {
                    var name = vv.name;
                    var type = vv.type;
                    var expr = vv.expr;
                    var fields:Array<{field:String, expr:Expr}> = [
                        {field:"name", expr:toString(name, p)},
                        {field:"type", expr:toOpt(toCType, type, p)},
                        {field:"expr", expr:toOpt(toExpr, expr, p)}
                    ];
                    return toObj(fields, p);
                }, vl, p)]);
            case EFunction(name, f):
                expr("EFunction", [toOpt(toString, name, p), toFun(f, p)]);
            case EBlock(el):
                expr("EBlock", [toExprArray(el, p)]);
            case EFor(e1, e2):
                expr("EFor", [loop(e1), loop(e2)]);
            case EIn(e1, e2):
                expr("EIn", [loop(e1), loop(e2)]);
            case EIf(e1, e2, eelse):
                expr("EIf", [loop(e1), loop(e2), toOpt(toExpr, eelse, p)]);
            case EWhile(e1, e2, normalWhile):
                expr("EWhile", [loop(e1), loop(e2), toBool(normalWhile, p)]);
            case ESwitch(e1, cases, def):
                function scase(swc:Case, p:Position):Expr {
                    var el = swc.values;
                    var eg = swc.guard;
                    var e = swc.expr;
                    return toObj([{field:"values", expr:toExprArray(el, p)}, {field:"guard", expr:toOpt(toExpr, eg, p)}, {field:"expr", expr:toOpt(toExpr, e, p)}], p);
                }
                expr("ESwitch", [loop(e1), toArray(scase, cases, p), toOpt(
                    function(def2:Null<Expr>, p:Position):Expr {
                        return toOpt(function(def3:Expr, p:Position):Expr {
                            return toExpr(def3, p);
                        }, def2, p);
                    }, def, p)]);
            case ETry(e1, catches):
                function scatch(c:Catch, p:Position):Expr {
                    var n = c.name;
                    var t = c.type;
                    var e = c.expr;
                    return toObj([{field:"name", expr:toString(n, p)}, {field:"type", expr:toCType(t, p)}, {field:"expr", expr:loop(e)}], p);
                }
                expr("ETry", [loop(e1), toArray(scatch, catches, p)]);
            case EReturn(eo):
                expr("EReturn", [toOpt(toExpr, eo, p)]);
            case EBreak:
                expr("EBreak", []);
            case EContinue:
                expr("EContinue", []);
            case EUntyped(e):
                expr("EUntyped", [loop(e)]);
            case EThrow(e):
                expr("EThrow", [loop(e)]);
            case ECast(e, ct):
                expr("ECast", [loop(e), toOpt(toCType, ct, p)]);
            case EDisplay(e, flag):
                expr("EDisplay", [loop(e), toBool(flag, p)]);
            case EDisplayNew(t):
                expr("EDisplayNew", [toTPath(t, p)]);
            case ETernary(e1, e2, e3):
                expr("ETernary", [loop(e1), loop(e2), loop(e3)]);
            case ECheckType(e1, ct):
                expr("ECheckType", [loop(e1), toCType(ct, p)]);
            case EMeta(md, e1):
                switch(md.name){
                case "$" | "$e":
                    e1;
                case "$a":
                    switch(e1.expr){
                    case EArrayDecl(el): expr("EArrayDecl", [toExprArray(el, p)]);
                    default: expr("EArrayDecl", [e1]);
                    }
                case "$b":
                    expr("EBlock", [e1]);
                case "$v":
                    {expr:ECall(
                        {expr:EField(
                            {expr:EField(
                                {expr:EField(
                                    {expr:EConst(CIdent("haxe")),
                                    pos:p},
                                    "macro"
                                ),
                                pos:p},
                                "Context"
                            ),
                            pos:p},
                            "makeExpr"
                        ),
                        pos:p},
                        [e, toPos(e.pos)]
                    ),
                    pos:p};
                case "$i":
                    expr("EConst", [mkEnum("Constant", "CIdent", [e1], e1.pos)]);
                case "$p":
                    {expr:ECall(
                        {expr:EField(
                            {expr:EField(
                                {expr:EField(
                                    {expr:EConst(CIdent("haxe")),
                                    pos:p},
                                    "macro"
                                ),
                                pos:p},
                                "ExprTools"
                            ),
                            pos:p},
                            "toFieldExpr"
                        ),
                        pos:p},
                        [e]
                    ),
                    pos:p};
                case ":pos" if (md.params.length == 1):
                    var old = curPos;
                    curPos = md.params[0];
                    var e = loop(e1);
                    curPos = old;
                    e;
                default: expr("EMeta", [
                        toObj([
                            {field:"name",expr:toString(md.name, p)},
                            {field:"params",expr:toExprArray(md.params, p)},
                            {field:"pos",expr:toPos(p)}
                        ], p),
                        loop(e1)
                    ]);
                }
        }
    }

    function toTParamDecl(t:TypeParamDecl, p:Position):Expr{
        var params = [];
        for (tp in t.params){
            params.push(toTParamDecl(tp,p));
        }

        var constraints = [];
        for (c in t.constraints){
            constraints.push(toCType(c,p));
        }

        return toObj([
            {field:"name", expr:toString(t.name,p)},
            {field:"params", expr:{expr:EArrayDecl(params),pos:p}},
            {field:"constraints", expr:{expr:EArrayDecl(constraints),pos:p}}
        ],p);
    }

    public function toTypeDef(td:TypeDecl):Expr{
        var p = td.pos;

        switch(td.decl){
        case EClass(d):
            var ext = null;
            var impl = [];
            var interf = false;

            for (f in d.flags){
                switch(f){
                    case HExtern | HPrivate:
                    case HInterface: interf = true;
                    case HExtends(t): ext = toTPath(t, td.pos);
                    case HImplements(i): impl.push(toTPath(i, td.pos));
                }
            }

            var params = [];
            for (par in d.params){
                params.push(toTParamDecl(par,p));
            }

            var isExtern = false;
            for (f in d.flags){
                switch(f){
                case HExtern: isExtern = true; break;
                default:
                }
            }

            var kindParams = [];

            if (ext == null){
                kindParams.push({expr:EConst(CIdent("null")),pos:p});
            }
            else {
                kindParams.push(ext);
            }

            kindParams.push({expr:EArrayDecl(impl),pos:p});
            kindParams.push(toBool(interf, p));

            var fields = [];
            for (d in d.data){
                fields.push(toCField(d,p));
            }

            return toObj([
                {field:"pack", expr:{expr:EArrayDecl([]),pos:p}},
                {field:"name", expr:toString(d.name, p)},
                {field:"pos", expr:(toPos(p))},
                {field:"meta", expr:toMeta(d.meta, p)},
                {field:"params", expr:{expr:EArrayDecl(params),pos:p}},
                {field:"isExtern", expr:toBool(isExtern, p)},
                {field:"kind", expr:mkEnum("TypeDefKind", "TDClass", kindParams, p)},
                {field:"fields", expr:{expr:EArrayDecl(fields), pos:p}}
            ], td.pos);
        default: throw "Invalid type for reification";
        }
    }
}
