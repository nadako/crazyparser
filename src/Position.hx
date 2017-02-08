class Position {
    public var start:Int;
    public var end:Int;
    public function new(start, end) {
        this.start = start;
        this.end = end;
    }
    public function toString() {
        return '[$start..$end)';
    }
}
