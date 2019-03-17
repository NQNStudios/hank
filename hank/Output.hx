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
            var findBraceExpression = buffer.findNestedExpression('{', '}');
            switch (findBraceExpression) {
                case Some(slice):
                    endSegment = slice.start;
                default:
            }
            if (endSegment == buffer.length() || endSegment != 0) {
                var peekLine = buffer.peekLine().unwrap();
                trace('peek: $peekLine');
                if (peekLine.length < endSegment) {
                    var text = buffer.takeLine().unwrap();
                    trace(text);
                    if (text.length > 0) {
                        parts.push(Text(text));
                    }
                    break;
                } else {
                    var text = buffer.take(endSegment);
                    trace(text);
                    parts.push(Text(text));
                }
            } else {
                parts.push(parseBraceExpression(buffer));
            }
        }

        // If the last output is Text, it should be trimmed at the end.
        if (parts.length > 0) {
            var lastPart = parts[parts.length - 1];
            switch(lastPart) {
                case Text(t):
                    parts[parts.length -1] = Text(StringTools.rtrim(t));
                default:
            }
        }

        // TODO parse out optional text parts

        return new Output(parts);
    }

    public static function parseBraceExpression(buffer: HankBuffer): OutputType {
        switch (Alt.parse(buffer)) {
            case Some(altExpression):
                return AltExpression(altExpression);
            default:
                return parseHaxeExpression(buffer);
        }
    }

    public static function parseHaxeExpression(buffer: HankBuffer): OutputType {
        var rawExpression = buffer.findNestedExpression('{', '}').unwrap().checkValue();
        // Strip out the enclosing braces
        var hExpression = rawExpression.substr(1, rawExpression.length - 2);

        // TODO process quasiquotes??

        buffer.take(rawExpression.length);
        return HExpression(hExpression);
    }
}