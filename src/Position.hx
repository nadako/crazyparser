class Position {
    public var file:String;
    public var min:Int;
    public var max:Int;

    public function new(file, min, max) {
        this.file = file;
        this.min = min;
        this.max = max;
    }

    public function toString():String {
        return '[$min..$max)';
    }

    static public function union(p1:Position, p2:Position) {
        return new Position(p1.file, p1.min < p2.min ? p1.min : p2.min, p1.max > p2.max ? p1.max : p2.max);
    }
}
