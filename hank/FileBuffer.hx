package hank;

import haxe.ds.Option;

/**
 A position in a FileBuffer, used for debugging.
**/
typedef Position = {
    var file: String;
    var line: Int;
    var column: Int;
}

/**
 Helper class for reading/parsing information from a file.
**/
class FileBuffer {
    var path: String;
    var buffer: String;
    var line: Int = 1;
    var column: Int = 0;

    public function new(path: String) {
        buffer = sys.io.File.getContent(path);
        this.path = path;
    }

    public function position(): Position {
        return {
            file: path,
            line: line,
            column: column
        };
    }

    /** Peek through the buffer until encountering one of the given terminator sequences
    @param eofTerminates Whether the end of the file is also a valid terminator
    **/
    public function peekUntil(terminators: Array<String>, eofTerminates: Bool = false): Option<String> {
        if (buffer.length == 0) return None;

        var index = buffer.length;

        for (terminator in terminators) {
            var nextIndex = buffer.indexOf(terminator);
            index = (nextIndex != -1 && nextIndex < index) ? nextIndex : index;
        }

        return if (index < buffer.length || eofTerminates) {
            Some(buffer.substr(0, index));
        } else {
            None;
        }
    }

    /**
     Drop the given string from the front of buffer, updating the current position
    **/
    public function drop(s: String) {
        var lines = s.split('\n');
        if (lines.length > 1) {
            line += lines.length - 1;
            column = lines[lines.length -1].length;
        } else {
            column += lines[lines.length-1].length;
        }
        var dropped = buffer.substr(0, s.length);
        if (dropped != s) {
            throw 'FileBuffer drop error at ${position()}: Expected to drop ${s} but was ${dropped}';
        }

        buffer = buffer.substr(s.length);
    }

    /** Take data from the file until encountering one of the given terminator sequences. **/
    public function takeUntil(terminators: Array<String>, eofTerminates: Bool = false, dropTerminator = true): Option<String> {
        return switch (peekUntil(terminators, eofTerminates)) {
            case Some(s):
                // Remove the desired data from the buffer
                drop(s);

                // Remove the terminator that followed the data from the buffer
                var nextTerminator = '';
                for (terminator in terminators) {
                    if (buffer.indexOf(terminator) == 0) {
                        if (dropTerminator) {
                            drop(terminator);
                        }
                        break;
                    }
                }

                // Return the desired data
                Some(s);
            case None:
                None;
        }
    }

    /** Take the specified number of characters from the file **/
    public function take(chars: Int) {
        var data = buffer.substr(0, chars);
        drop(data);
        return data;
    }

    /** Take the next line of data from the file. (Stops for comments)
    @param trimmed Which sides of the line to trim ('r' 'l', 'lr', or 'rl')
    **/
    public function takeLine(trimmed = ''): Option<String> {
        var nextLine = if (StringTools.startsWith(buffer, '//') || StringTools.startsWith(buffer, '/*')) {
            takeUntil(['\n'], true);
        } else {
            switch (peekWhichComesNext(['\n', '//', '/*'])) {
                case Some([0, _]) | None:
                    takeUntil(['\n'], true);
                // Preserve // and /* if they terminate a line
                default:
                    takeUntil(['//', '/*'], false, false);
            }
        }
        return switch (nextLine) {
            case Some(nextLine):
                if (trimmed.indexOf('r') != -1) {
                    nextLine = StringTools.rtrim(nextLine);
                }
                if (trimmed.indexOf('l') != -1) {
                    nextLine = StringTools.ltrim(nextLine);
                }
                Some(nextLine);
            case None:
                None;
        }
    }

    public function peekWhichComesNext(terminators: Array<String>): Option<Array<Int>> {
        var peek = peekUntil(terminators);
        switch (peek) {
            case Some(peekedPast):
                var index = peekedPast.length;
                var which = -1;
                for (i in 0...terminators.length) {
                    var terminator = terminators[i];
                    if (StringTools.startsWith(buffer.substr(index), terminator)) {
                        which = i;
                        break;
                    }
                }
                return Some([which, index]);
            case None:
                return None;
        }
    }

    /** Give text back to the buffer **/
    public function give(s: String) {
        buffer = s + buffer;
    }
}