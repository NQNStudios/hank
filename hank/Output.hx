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

        // First of all, split up the optional segments (ToggleOutputs) and parse them separately
        // TODO this doesn't work because it seeks ahead to the next bracket through ALL LINES of the buffer. This needs to only run when we're on an individual line
        var findBracketExpression = buffer.findNestedExpression('[', ']');
        switch (findBracketExpression) {
            case Some(slice):
                var part1 = buffer.take(slice.start);
                buffer.take(1);
                var part2 = buffer.take(slice.length-2);
                buffer.take(1);

                var parts = parse(HankBuffer.Dummy(part1)).parts;
                parts.push(ToggleOutput(parse(HankBuffer.Dummy(part2)), false));
                parts.push(ToggleOutput(parse(buffer), true));
                return new Output(parts);

            case None:
                // This is an individual Output to parse
        }


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

        // If the last output is Text, it could contain optional text or an inline divert. Or just need rtrimming.
        if (parts.length > 0) {
            var lastPart = parts[parts.length - 1];
            switch(lastPart) {
                case Text(t):
                    parts.remove(lastPart);
                    parts = parts.concat(parseLastText(t));
                default:
            }
        }

        // TODO parse out optional text parts

        return new Output(parts);
    }

    /** The last part of an output expression outside of braces can include an inline divert -> like_so **/
    public static function parseLastText(text: String): Array<OutputType> {
        var parts = [];

        var divertIndex = text.lastIndexOf('->');
        if (divertIndex != -1) {
            if (divertIndex != 0) {
                parts.push(Text(text.substr(0, divertIndex)));
            }
            var target = StringTools.trim(text.substr(divertIndex+2));
            parts.push(InlineDivert(target));
        } else {
            parts.push(Text(StringTools.rtrim(text)));
        }
        
        return parts;
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

        buffer.take(rawExpression.length);
        return HExpression(hExpression);
    }
}