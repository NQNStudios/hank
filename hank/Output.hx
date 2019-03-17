package hank;

using Extensions.OptionExtender;

enum OutputType {
    Text(t: String); // Pure text that is always displayed
    AltExpression(a: Alt);
    HExpression(h: String); // An embedded Haxe expression whose value will be inserted
    InlineDivert(t: String); // A divert statement on the same line as an output sequence.
    ToggleOutput(o: Output, invert: Bool); // Output that will sometimes be displayed (i.e. [bracketed] section in a choice text or the section following the bracketed section)
}

@:allow(tests.ParserTest)
class Output {
    var parts: Array<OutputType> = [];

    public function new(?parts: Array<OutputType>) {
        this.parts = if (parts != null) {
            parts;
        } else {
            [];
        };
    }

    public static function parse(buffer: HankBuffer): Output {
        var parts = [];

        while (!buffer.isEmpty()) {
            var endSegment = buffer.length();
            var findHaxeExpression = buffer.findNestedExpression('{', '}');
            var findAltExpression = buffer.findNestedExpression('{{', '}}', 0, false); // Single brace expressions trip up the double brace search, so don't throw exceptions
            switch (findHaxeExpression) {
                case Some(slice):
                    if (slice.start < endSegment)
                        endSegment = slice.start;
                default:
            }
            switch (findAltExpression) {
                case Some(slice):
                    if (slice.start < endSegment)
                        endSegment = slice.start;
                default:
            }
            if (endSegment == buffer.length() || endSegment != 0) {
                var peekLine = buffer.peekLine().unwrap();
                if (peekLine.length < endSegment) {
                    parts.push(Text(buffer.takeLine().unwrap()));
                    break;
                } else {
                    parts.push(Text(buffer.take(endSegment)));
                }
            } else {
                if (buffer.indexOf('{{') == 0) {
                    parts.push(parseAltExpression(buffer));
                } else {
                    parts.push(parseHaxeExpression(buffer));
                }
            }
        }

        // Parse out optional text parts

        // Find the first level of nested brace, expressions, and parse them out

        return new Output(parts);
    }

    public static function parseHaxeExpression(buffer: HankBuffer) {
        trace('parseHaxeExpresion');
        var rawExpression = buffer.findNestedExpression('{', '}').unwrap().checkValue();
        // Strip out the enclosing braces
        var hExpression = rawExpression.substr(1, rawExpression.length - 2);

        // TODO process quasiquotes??

        buffer.take(rawExpression.length);
        return HExpression(hExpression);
    }

    public static function parseAltExpression(buffer: HankBuffer) {
        trace('parseAltExpression');
        return AltExpression({behavior: Cycle, outputs:[]});
    }
}