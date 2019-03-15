package hank;

enum OutputType {
    Text(t: String); // Pure text that is always displayed
    // Alt(a: Alt); // TODO re-implement Alts recursively. Each alt branch should be an Output
    HExpression(h: String); // An embedded Haxe expression whose value will be inserted
    InlineDivert(t: String); // A divert statement on the same line as an output sequence.
    InlineComment(c: String); // A block comment in the middle of an output sequence
    ToggleOutput(o: Output, invert: Bool); // Output that will sometimes be displayed (i.e. [bracketed] section in a choice text or the section following the bracketed section)
}

@:allow(tests.ParserTest)
class Output {
    var parts: Array<OutputType> = [];

    private function new(parts: Array<OutputType>) {
        this.parts = parts;
    }

    public static function parse(expression): Output {
        return new Output([]);
    }
}