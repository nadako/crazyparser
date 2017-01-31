package haxeparser;

class Token {
    public var kind:TokenKind;
    public var pos:Position;
    public var space = "";

    public function new(kind, pos) {
        this.kind = kind;
        this.pos = pos;
    }

    public inline function toString() {
        return TokenPrinter.toString(kind);
    }
}

enum TokenKind {
    TkKeyword(k:Keyword);
    TkConst(c:Constant);
    TkSharp(s:String);
    TkDollar(s:String);
    TkPlusPlus;
    TkMinusMinus;
    TkTilde;
    TkExclamation;
    TkBinop(op:Binop);
    TkComment(s:String);
    TkCommentLine(s:String);
    TkColon;
    TkSemicolon;
    TkDot;
    TkComma;
    TkArrow;
    TkQuestion;
    TkAt;
    TkBracketOpen;
    TkBracketClose;
    TkBraceOpen;
    TkBraceClose;
    TkParenOpen;
    TkParenClose;
    TkEof;
    TkInvalid;
}

class TokenPrinter {

    static function printBinop(op:Binop) return switch(op) {
        case OpAdd: "+";
        case OpMult: "*";
        case OpDiv: "/";
        case OpSub: "-";
        case OpAssign: "=";
        case OpEq: "==";
        case OpNotEq: "!=";
        case OpGt: ">";
        case OpGte: ">=";
        case OpLt: "<";
        case OpLte: "<=";
        case OpAnd: "&";
        case OpOr: "|";
        case OpXor: "^";
        case OpBoolAnd: "&&";
        case OpBoolOr: "||";
        case OpShl: "<<";
        case OpShr: ">>";
        case OpUShr: ">>>";
        case OpMod: "%";
        case OpInterval: "...";
        case OpArrow: "=>";
        case OpAssignOp(op):
            printBinop(op)
            + "=";
    }

    static public function toString(kind:TokenKind) {
        return switch (kind) {
            case TkKeyword(k): k.getName().substr(3).toLowerCase();
            case TkConst(CInt(s) | CFloat(s) | CIdent(s)): s;
            case TkConst(CString(s)): '"$s"';
            case TkConst(CRegexp(r, opt)): '~/$r/$opt';
            case TkSharp(s): '#$s';
            case TkDollar(s): '$$$s';
            case TkPlusPlus: "++";
            case TkMinusMinus: "--";
            case TkExclamation: "!";
            case TkTilde: "~";
            case TkBinop(op): printBinop(op);
            case TkComment(s): '/*$s*/';
            case TkCommentLine(s): '//$s';
            case TkSemicolon: ";";
            case TkDot: ".";
            case TkColon: ":";
            case TkArrow: "->";
            case TkComma: ",";
            case TkBracketOpen: "[";
            case TkBracketClose: "]";
            case TkBraceOpen: "{";
            case TkBraceClose: "}";
            case TkParenOpen: "(";
            case TkParenClose: ")";
            case TkQuestion: "?";
            case TkAt: "@";
            case TkEof: "<eof>";
            case TkInvalid: "<invalid>";
        }
    }
}

enum Constant {
    CInt(v:String);
    CFloat(f:String);
    CString(s:String);
    CIdent(s:String);
    CRegexp(r:String, opt:String);
}

enum Binop {
    OpAdd;
    OpMult;
    OpDiv;
    OpSub;
    OpAssign;
    OpEq;
    OpNotEq;
    OpGt;
    OpGte;
    OpLt;
    OpLte;
    OpAnd;
    OpOr;
    OpXor;
    OpBoolAnd;
    OpBoolOr;
    OpShl;
    OpShr;
    OpUShr;
    OpMod;
    OpAssignOp(op:Binop);
    OpInterval;
    OpArrow;
}

enum Unop {
    OpIncrement;
    OpDecrement;
    OpNot;
    OpNeg;
    OpNegBits;
}

typedef Expr = {
    var expr:ExprDef;
    var pos:Position;
}


typedef Case = {
    var values:Array<Expr>;
    @:optional var guard:Null<Expr>;
    var expr:Null<Expr>;
}

typedef Var = {
    var name:String;
    var type:Null<ComplexType>;
    var expr:Null<Expr>;
}

typedef Catch = {
    var name:String;
    var type:ComplexType;
    var expr:Expr;
}

enum ExprDef {
    EConst( c : Constant );
    EArray( e1 : Expr, e2 : Expr );
    EBinop( op : Binop, e1 : Expr, e2 : Expr );
    EField( e : Expr, field : String );
    EParenthesis( e : Expr );
    EObjectDecl( fields : Array<{ field : String, expr : Expr }> );
    EArrayDecl( values : Array<Expr> );
    ECall( e : Expr, params : Array<Expr> );
    ENew( t : TypePath, params : Array<Expr> );
    EUnop( op : Unop, postFix : Bool, e : Expr );
    EVars( vars : Array<Var> );
    EFunction( name : Null<String>, f : Function );
    EBlock( exprs : Array<Expr> );
    EFor( it : Expr, expr : Expr );
    EIn( e1 : Expr, e2 : Expr );
    EIf( econd : Expr, eif : Expr, eelse : Null<Expr> );
    EWhile( econd : Expr, e : Expr, normalWhile : Bool );
    ESwitch( e : Expr, cases : Array<Case>, edef : Null<Expr> );
    ETry( e : Expr, catches : Array<Catch> );
    EReturn( ?e : Null<Expr> );
    EBreak;
    EContinue;
    EUntyped( e : Expr );
    EThrow( e : Expr );
    ECast( e : Expr, t : Null<ComplexType> );
    EDisplay( e : Expr, isCall : Bool );
    EDisplayNew( t : TypePath );
    ETernary( econd : Expr, eif : Expr, eelse : Expr );
    ECheckType( e : Expr, t : ComplexType );
    EMeta( s : MetadataEntry, e : Expr );
}

enum ComplexType {
    TPath( p : TypePath );
    TFunction( args : Array<ComplexType>, ret : ComplexType );
    TAnonymous( fields : Array<Field> );
    TParent( t : ComplexType );
    TExtend( p : Array<TypePath>, fields : Array<Field> );
    TOptional( t : ComplexType );
}

typedef TypePath = {
    var pack : Array<String>;
    var name : String;
    @:optional var params : Array<TypeParam>;
    @:optional var sub : Null<String>;
}

enum TypeParam {
    TPType( t : ComplexType );
    TPExpr( e : Expr );
}

typedef TypeParamDecl = {
    var name : String;
    @:optional var constraints : Array<ComplexType>;
    @:optional var params : Array<TypeParamDecl>;
    @:optional var meta : Metadata;
}

typedef Function = {
    var args : Array<FunctionArg>;
    var ret : Null<ComplexType>;
    var expr : Null<Expr>;
    @:optional var params : Array<TypeParamDecl>;
}

typedef FunctionArg = {
    var name : String;
    @:optional var opt : Bool;
    var type : Null<ComplexType>;
    @:optional var value : Null<Expr>;
    @:optional var meta : Metadata;
}

typedef MetadataEntry = {
    var name : String;
    @:optional var params : Array<Expr>;
    var pos : Position;
}

typedef Metadata = Array<MetadataEntry>;

typedef Field = {
    var name : String;
    @:optional var access : Array<Access>;
    var kind : FieldType;
    var pos : Position;
    @:optional var meta : Metadata;
}

enum Access {
    APublic;
    APrivate;
    AStatic;
    AOverride;
    ADynamic;
    AInline;
    AMacro;
}

enum FieldType {
    FVar( t : Null<ComplexType>, ?e : Null<Expr> );
    FFun( f : Function );
    FProp( get : String, set : String, ?t : Null<ComplexType>, ?e : Null<Expr> );
}


enum ImportMode {
    INormal;
    IAsName(alias:String);
    IAll;
}

typedef ImportExpr = {
    var path: Array<{pos:Position, name:String}>;
    var mode: ImportMode;
}

enum Keyword {
    KwFunction;
    KwClass;
    KwVar;
    KwIf;
    KwElse;
    KwWhile;
    KwDo;
    KwFor;
    KwBreak;
    KwContinue;
    KwReturn;
    KwExtends;
    KwImplements;
    KwImport;
    KwSwitch;
    KwCase;
    KwDefault;
    KwStatic;
    KwPublic;
    KwPrivate;
    KwTry;
    KwCatch;
    KwNew;
    KwThis;
    KwThrow;
    KwExtern;
    KwEnum;
    KwIn;
    KwInterface;
    KwUntyped;
    KwCast;
    KwOverride;
    KwTypedef;
    KwDynamic;
    KwPackage;
    KwInline;
    KwUsing;
    KwNull;
    KwTrue;
    KwFalse;
    KwAbstract;
    KwMacro;
}

class KeywordPrinter {
    static public function toString(kwd:Keyword) {
        return switch (kwd) {
            case KwFunction: "function";
            case KwClass: "class";
            case KwVar: "var";
            case KwIf: "if";
            case KwElse: "else";
            case KwWhile: "while";
            case KwDo: "do";
            case KwFor: "for";
            case KwBreak: "break";
            case KwContinue: "continue";
            case KwReturn: "return";
            case KwExtends: "extends";
            case KwImplements: "implements";
            case KwImport: "import";
            case KwSwitch: "switch";
            case KwCase: "case";
            case KwDefault: "default";
            case KwStatic: "static";
            case KwPublic: "public";
            case KwPrivate: "private";
            case KwTry: "try";
            case KwCatch: "catch";
            case KwNew: "new";
            case KwThis: "this";
            case KwThrow: "throw";
            case KwExtern: "extern";
            case KwEnum: "enum";
            case KwIn: "in";
            case KwInterface: "interface";
            case KwUntyped: "untyped";
            case KwCast: "cast";
            case KwOverride: "override";
            case KwTypedef: "typedef";
            case KwDynamic: "dynamic";
            case KwPackage: "package";
            case KwInline: "inline";
            case KwUsing: "using";
            case KwNull: "null";
            case KwTrue: "true";
            case KwFalse: "false";
            case KwAbstract: "abstract";
            case KwMacro: "macro";
        }
    }
}

typedef EnumConstructor = {
    name : String,
    meta: Metadata,
    args: Array<{ name: String, opt: Bool, type: ComplexType}>,
    pos: Position,
    params: Array<TypeParamDecl>,
    type: Null<ComplexType>
}

typedef Definition<A,B> = {
    name:String,
    params:Array<TypeParamDecl>,
    meta:Metadata,
    flags:Array<A>,
    data:B
}

enum TypeDef {
    EClass(d:Definition<ClassFlag, Array<Field>>);
    EEnum(d:Definition<EnumFlag, Array<EnumConstructor>>);
    EAbstract(a:Definition<AbstractFlag, Array<Field>>);
    EImport(sl:Array<{pack:String, pos:Position}>, mode:ImportMode);
    ETypedef(d:Definition<EnumFlag, ComplexType>);
    EUsing(path:TypePath);
}

typedef TypeDecl = {
    decl : TypeDef,
    pos : Position
}

enum ClassFlag {
    HInterface;
    HExtern;
    HPrivate;
    HExtends(t:TypePath);
    HImplements(t:TypePath);
}

enum AbstractFlag {
    APrivAbstract;
    AFromType(ct:ComplexType);
    AToType(ct:ComplexType);
    AIsType(ct:ComplexType);
    AExtern;
}

enum EnumFlag {
    EPrivate;
    EExtern;
}
