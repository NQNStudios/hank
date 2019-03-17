package hank;

import haxe.ds.Option;

/**
 A position in a HankBuffer, used for debugging.
**/
class Position {
    public var file: String;
    public var line: Int;
    public var column: Int;

    public function new(file: String, line: Int, column: Int) {
        this.file = file;
        this.line = line;
        this.column = column;
    }

    public function equals(other: Position) {
        return file == other.file && line == other.line && column == other.column;
    }
}

/**
Reference to a slice of the buffer, which expires when the buffer changes its state.
**/
@:allow(hank.HankBuffer)
class BufferSlice {
    public var start(default, null): Int;
    public var length(default, null): Int;
    var anchorPosition: Position;
    var buffer: HankBuffer;

    private function new(start: Int, length: Int, buffer: HankBuffer) {
        this.start = start;
        this.length = length;
        this.anchorPosition = buffer.position();
        this.buffer = buffer;
    }

    public function checkValue() {
        if (!buffer.position().equals(anchorPosition)) {
            throw 'Tried to access an expired BufferSlice.';
        }
        return buffer.peekAhead(start, length);
    }
}

typedef BufferOutput = {
    output: String,
    terminator: String
};

/**
 Helper class for reading/parsing information from a string buffer. Completely drops comments
**/
class HankBuffer {
    var path: String;
    var cleanBuffer: String;
    var rawBuffer: String;
    var line: Int;
    var column: Int;

    private function new(path: String, rawBuffer: String, line: Int = 1, column: Int = 1) {
        this.path = path;
        this.rawBuffer = rawBuffer;
        // Keep a clean buffer for returning data without comments getting in the way
        this.cleanBuffer = stripComments(rawBuffer, '//', '\n', false);
        this.cleanBuffer = stripComments(cleanBuffer, '/*', '*/', true);
        this.line = line;
        this.column = column;
    }

    public static function FromFile(path: String) {
        // Keep a raw buffer of the file for tracking accurate file positions
        var rawBuffer = sys.io.File.getContent(path);
        return new HankBuffer(path, rawBuffer);
    }

    function stripComments(s: String, o: String, c: String, dc: Bool): String {
        while (s.indexOf(o) != -1) {
            var start = s.indexOf(o);
            var end = s.indexOf(c, start);
            if (end == -1) {
                s = s.substr(0, start);
            } else {
                if (dc) end += c.length;
                s = s.substr(0, start) + s.substr(end);
            }
        }
        return s;
    }

    public function indexOf(s: String) {
        return cleanBuffer.indexOf(s);
    }

    public function length(): Int {
        return cleanBuffer.length;
    }

    public function position(): Position {
        return new Position(path, line, column);
    }

    /** Peek at contents buffer waiting further ahead in the buffer **/
    public function peekAhead(start: Int, length: Int) {
        return cleanBuffer.substr(start, length);
    }

    /** Peek through the buffer until encountering one of the given terminator sequences
    @param eofTerminates Whether the end of the file is also a valid terminator
    **/
    public function peekUntil(terminators: Array<String>, eofTerminates: Bool = false, raw: Bool = false): Option<BufferOutput> {
        var buffer = raw ? rawBuffer : cleanBuffer;
        if (buffer.length == 0) return None;

        var index = buffer.length;

        var whichTerminator = '';
        for (terminator in terminators) {
            var nextIndex = buffer.indexOf(terminator);
            if (nextIndex != -1 && nextIndex < index) {
                index = nextIndex;
                whichTerminator = terminator;
            }
        }

        return if (index < buffer.length || eofTerminates) {
            Some({
                output: buffer.substr(0, index),
                terminator: whichTerminator
            });
        } else {
            None;
        }
    }

    /**
     Drop the given string from the front of the raw buffer, updating the current position according to the raw buffer
    **/
    function dropRaw(s: String) {
        var actual = rawBuffer.substr(0, s.length);
        if (actual != s) {
            throw 'Expected to drop "${s}" but was "${actual}"';
        }

        var lines = s.split('\n');
        if (lines.length > 1) {
            line += lines.length - 1;
            column = lines[lines.length -1].length+1;
        } else {
            column += lines[0].length;
        }

        rawBuffer = rawBuffer.substr(s.length);
    }

    /** Drop text directly from the clean buffer **/
    function dropClean(s: String) {
        var actual = cleanBuffer.substr(0, s.length);

        if (actual != s) {
            throw 'Expected to drop "${s}" but was "${actual}"';
        }

        cleanBuffer = cleanBuffer.substr(s.length);
    }

    /**
     Drop the given string from the front of the unified buffer object, keeping the two back-end buffers synchronized
    **/
    public function drop(s: String) {
        var untilNextComment = peekUntil(['//', '/*'], false, true);

        switch (untilNextComment) {
            case Some({output: rawS, terminator: commentOpener}) if (rawS.length < s.length):
                var commentTerminator = switch (commentOpener) {
                    case '//': '\n';
                    case '/*': '*/';
                    default: throw 'FUBAR';
                }
                dropRaw(rawS + commentOpener);
                dropClean(rawS);
                var untilEndOfComment = peekUntil([commentTerminator], true, true);
                switch (untilEndOfComment) {
                    case Some({output: comment, terminator: _}):
                        dropRaw(comment);
                        if (commentTerminator != '\n') {
                            dropRaw(commentTerminator);
                        }
                        // Drop the rest of the clean sequence
                        var rest = s.substr(rawS.length);

                        drop(rest);
                    default: throw 'FUBAR';
                }
            default:
                dropClean(s);
                dropRaw(s);
        }
    }

    /** Take data from the file until encountering one of the given terminator sequences. **/
    public function takeUntil(terminators: Array<String>, eofTerminates: Bool = false, dropTerminator = true): Option<BufferOutput> {
        return switch (peekUntil(terminators, eofTerminates)) {
            case Some({output: s, terminator: t}):
                // Remove the desired data from the buffer
                drop(s);

                // Remove the terminator that followed the data from the buffer
                if (dropTerminator) {
                    drop(t);
                }

                // Return the desired data
                Some({output: s, terminator: t});
            case None:
                None;
        }
    }

    public function take(chars: Int) {
        if (cleanBuffer.length < chars) {
            throw 'Not enough characters left in buffer.';
        }
        var data = cleanBuffer.substr(0, chars);
        drop(data);
        return data;
    }

    /** DRY Helper for peekLine() and takeLine() **/
    function getLine(trimmed: String, retriever: Array<String> -> Bool -> Bool -> Option<BufferOutput>): Option<String> {
        var nextLine = retriever(['\n'], true, true);
        return switch (nextLine) {
            case Some({output: nextLine, terminator: _}):
                if (trimmed.indexOf('r') != -1) {
                    nextLine = StringTools.rtrim(nextLine);
                }
                if (trimmed.indexOf('l') != -1) {
                    nextLine = StringTools.ltrim(nextLine);
                }
                Some(nextLine);
            case None:
                None;
        };
    }

    /** Peek the next line of data from the file.
    @param trimmed Which sides of the line to trim ('r' 'l', 'lr', or 'rl')
    **/
    public function peekLine(trimmed = ''): Option<String> {
        return getLine(trimmed, peekUntil);
    }

    /** Take the next line of data from the file.
    @param trimmed Which sides of the line to trim ('r' 'l', 'lr', or 'rl')
    **/
    public function takeLine(trimmed = ''): Option<String> {
        return getLine(trimmed, takeUntil);
    }

    public function skipWhitespace() {
        var whitespace = cleanBuffer.substr(0, cleanBuffer.length - StringTools.ltrim(cleanBuffer).length);
        drop(whitespace);
    }

    public function isEmpty() {
        return cleanBuffer.length == 0;
    }

    /** Return the start index and length of number of characters left the buffer before a nestable expression terminates **/
    public function findNestedExpression(o: String, c: String, start: Int = 0, throwExceptions: Bool = true): Option<BufferSlice> {
        var startIdx = start;
        var endIdx = start;
        var depth = 0;


        var nextIdx = start;
        do {
            var nextOpeningIdx = cleanBuffer.indexOf(o, nextIdx);
            var nextClosingIdx = cleanBuffer.indexOf(c, nextIdx);

            if (nextOpeningIdx == -1 && nextClosingIdx == -1) {
                return None;
            } else if (depth == 0 && nextOpeningIdx == -1 ) {
                if (throwExceptions)
                    throw 'Your input file $path has an expression with an unmatched closing operator $c';
                else
                    return None;
            }
            else if (depth != 0 && nextClosingIdx == -1) {
                if (throwExceptions)
                    throw 'Your input file $path has an expression with an unmatched opening operator $o';
                else
                    return None;
            }
            else if (nextOpeningIdx != -1 && nextOpeningIdx < nextClosingIdx) {
                if (depth == 0) {
                    startIdx = nextOpeningIdx;
                }
                depth += 1;
                nextIdx = nextOpeningIdx + o.length;
            } else {
                depth -= 1;
                nextIdx = nextClosingIdx + c.length;
                endIdx = nextClosingIdx + c.length;
            }

        } while (depth > 0 && nextIdx < cleanBuffer.length);

        return Some(new BufferSlice(startIdx, endIdx - startIdx, this));
    }
}